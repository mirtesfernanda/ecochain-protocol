// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title EcoStaking
 * @author Mirtes Fernanda Dutra da Silva
 * @notice Staking de ECO tokens com recompensa ajustada pelo preco ETH/USD
 *         via oracle Chainlink (interface inline — compativel com Remix).
 *
 * APR dinamico:
 *   - ETH/USD > $2000 => 15% ao ano
 *   - ETH/USD <= $2000 => 10% ao ano
 *
 * Seguranca:
 *   - ReentrancyGuard (OZ v5.0.0: utils/)
 *   - Ownable
 *   - Padrao CEI (Checks-Effects-Interactions)
 *   - Solidity ^0.8.20
 */

// Interface Chainlink inline (evita problemas de import no Remix)
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract EcoStaking is ReentrancyGuard, Ownable {

    IERC20 public immutable ecoToken;
    AggregatorV3Interface public immutable priceFeed;

    uint256 public constant BASE_APR             = 10;
    uint256 public constant BONUS_APR            = 15;
    uint256 public constant ETH_BONUS_THRESHOLD  = 2000 * 1e8; // 8 decimais Chainlink
    uint256 public constant SECONDS_PER_YEAR     = 365 days;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastClaim;
    }

    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardClaimed(address indexed user, uint256 reward);
    event OraclePriceRead(int256 price);

    constructor(
        address _ecoToken,
        address _priceFeed,
        address initialOwner
    ) Ownable(initialOwner) {
        ecoToken  = IERC20(_ecoToken);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    // ──────────────────────────────────────────────────────
    //  Funcoes principais
    // ──────────────────────────────────────────────────────

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "EcoStaking: valor zero");
        require(stakes[msg.sender].amount == 0, "EcoStaking: ja em stake, retire primeiro");

        bool ok = ecoToken.transferFrom(msg.sender, address(this), amount);
        require(ok, "EcoStaking: transferencia falhou");

        stakes[msg.sender] = StakeInfo({
            amount:    amount,
            startTime: block.timestamp,
            lastClaim: block.timestamp
        });
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake() external nonReentrant {
        StakeInfo storage info = stakes[msg.sender];
        require(info.amount > 0, "EcoStaking: sem stake ativo");

        uint256 reward    = _calcReward(msg.sender);
        uint256 principal = info.amount;

        // Valida saldo antes de alterar estado (fail-fast com mensagem clara)
        require(
            ecoToken.balanceOf(address(this)) >= principal,
            "EcoStaking: pool sem saldo para devolver principal - owner deve financiar"
        );

        // EFFECTS antes de INTERACTIONS (padrao CEI)
        totalStaked -= principal;
        delete stakes[msg.sender];

        // Devolve principal (sempre)
        bool okPrincipal = ecoToken.transfer(msg.sender, principal);
        require(okPrincipal, "EcoStaking: falha ao transferir principal");

        // Devolve recompensa apenas se o pool tiver saldo extra (opcional - nao reverte)
        uint256 rewardPaid = 0;
        if (reward > 0 && ecoToken.balanceOf(address(this)) >= reward) {
            ecoToken.transfer(msg.sender, reward);
            rewardPaid = reward;
        }

        emit Unstaked(msg.sender, principal, rewardPaid);
    }

    function claimReward() external nonReentrant {
        StakeInfo storage info = stakes[msg.sender];
        require(info.amount > 0, "EcoStaking: sem stake ativo");

        uint256 reward = _calcReward(msg.sender);
        require(reward > 0, "EcoStaking: sem recompensa");
        require(
            ecoToken.balanceOf(address(this)) >= info.amount + reward,
            "EcoStaking: reserva insuficiente - owner deve financiar o pool"
        );

        // EFFECTS antes de INTERACTIONS
        info.lastClaim = block.timestamp;

        ecoToken.transfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }

    function fundRewards(uint256 amount) external onlyOwner {
        ecoToken.transferFrom(msg.sender, address(this), amount);
    }

    // ──────────────────────────────────────────────────────
    //  Views
    // ──────────────────────────────────────────────────────

    function pendingReward(address user) external view returns (uint256) {
        StakeInfo storage info = stakes[user];
        if (info.amount == 0) return 0;
        uint256 apr     = _getApr();
        uint256 elapsed = block.timestamp - info.lastClaim;
        return (info.amount * apr * elapsed) / (100 * SECONDS_PER_YEAR);
    }

    function currentEthPrice() external view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }

    // ──────────────────────────────────────────────────────
    //  Internos
    // ──────────────────────────────────────────────────────

    function _calcReward(address user) internal view returns (uint256) {
        StakeInfo storage info = stakes[user];
        uint256 apr     = _getApr();
        uint256 elapsed = block.timestamp - info.lastClaim;
        return (info.amount * apr * elapsed) / (100 * SECONDS_PER_YEAR);
    }

    function _getApr() internal view returns (uint256) {
        try priceFeed.latestRoundData() returns (uint80, int256 answer, uint256, uint256, uint80) {
            if (answer > 0 && uint256(answer) > ETH_BONUS_THRESHOLD) {
                return BONUS_APR;
            }
        } catch {}
        return BASE_APR;
    }
}

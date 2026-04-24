// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title EcoDAO
 * @author Mirtes Fernanda Dutra da Silva
 * @notice Governanca simplificada (DAO) do protocolo EcoChain.
 *
 * Fluxo:
 *   1. Holder com >= 1000 ECO cria proposta
 *   2. Periodo de votacao: 3 dias (1 ECO = 1 voto)
 *   3. Finalizacao publica apos o periodo
 *   4. Owner executa proposta aprovada
 *
 * Seguranca:
 *   - ReentrancyGuard (OZ v5.0.0: utils/)
 *   - Ownable
 *   - Anti double-vote
 *   - Solidity ^0.8.20
 */
contract EcoDAO is Ownable, ReentrancyGuard {

    IERC20 public immutable ecoToken;

    uint256 public constant VOTING_PERIOD         = 3 days;
    uint256 public constant MIN_TOKENS_TO_PROPOSE = 1000 * 10 ** 18;

    enum ProposalState { Active, Approved, Rejected, Executed }

    struct Proposal {
        uint256       id;
        address       proposer;
        string        description;
        uint256       votesFor;
        uint256       votesAgainst;
        uint256       endTime;
        ProposalState state;
        bool          executed;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal)                 public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool inFavor, uint256 weight);
    event ProposalFinalized(uint256 indexed id, ProposalState state);
    event ProposalExecuted(uint256 indexed id);

    constructor(address _ecoToken, address initialOwner) Ownable(initialOwner) {
        ecoToken = IERC20(_ecoToken);
    }

    // ──────────────────────────────────────────────────────
    //  Criar proposta
    // ──────────────────────────────────────────────────────

    function propose(string calldata description) external returns (uint256) {
        require(
            ecoToken.balanceOf(msg.sender) >= MIN_TOKENS_TO_PROPOSE,
            "EcoDAO: tokens insuficientes"
        );

        uint256 id = proposalCount++;
        proposals[id] = Proposal({
            id:           id,
            proposer:     msg.sender,
            description:  description,
            votesFor:     0,
            votesAgainst: 0,
            endTime:      block.timestamp + VOTING_PERIOD,
            state:        ProposalState.Active,
            executed:     false
        });

        emit ProposalCreated(id, msg.sender, description);
        return id;
    }

    // ──────────────────────────────────────────────────────
    //  Votar
    // ──────────────────────────────────────────────────────

    function vote(uint256 proposalId, bool inFavor) external {
        Proposal storage p = proposals[proposalId];

        require(p.endTime != 0,                    "EcoDAO: proposta inexistente");
        require(block.timestamp < p.endTime,       "EcoDAO: votacao encerrada");
        require(p.state == ProposalState.Active,   "EcoDAO: nao esta ativa");
        require(!hasVoted[proposalId][msg.sender], "EcoDAO: ja votou nesta proposta");

        uint256 weight = ecoToken.balanceOf(msg.sender);
        require(weight > 0, "EcoDAO: sem tokens");

        hasVoted[proposalId][msg.sender] = true;

        if (inFavor) {
            p.votesFor     += weight;
        } else {
            p.votesAgainst += weight;
        }

        emit VoteCast(proposalId, msg.sender, inFavor, weight);
    }

    // ──────────────────────────────────────────────────────
    //  Finalizar e executar
    // ──────────────────────────────────────────────────────

    function finalize(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.endTime != 0,                  "EcoDAO: inexistente");
        require(block.timestamp >= p.endTime,    "EcoDAO: periodo ativo");
        require(p.state == ProposalState.Active, "EcoDAO: ja finalizada");

        p.state = p.votesFor > p.votesAgainst
            ? ProposalState.Approved
            : ProposalState.Rejected;

        emit ProposalFinalized(proposalId, p.state);
    }

    function execute(uint256 proposalId) external onlyOwner nonReentrant {
        Proposal storage p = proposals[proposalId];
        require(p.state == ProposalState.Approved, "EcoDAO: nao aprovada");
        require(!p.executed,                       "EcoDAO: ja executada");

        p.executed = true;
        p.state    = ProposalState.Executed;

        emit ProposalExecuted(proposalId);
    }

    // ──────────────────────────────────────────────────────
    //  Views
    // ──────────────────────────────────────────────────────

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return proposals[id];
    }

    function isActive(uint256 id) external view returns (bool) {
        return proposals[id].state == ProposalState.Active
            && block.timestamp < proposals[id].endTime;
    }
}

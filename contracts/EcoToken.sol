// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EcoToken (ECO)
 * @author Mirtes Fernanda Dutra da Silva
 * @notice Token ERC-20 do protocolo EcoChain — plataforma descentralizada
 *         de financiamento e rastreamento de projetos ambientais.
 * @dev Baseado em OpenZeppelin v5.0.0. Mintavel apenas pelo owner (Staking/DAO).
 */
contract EcoToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18; // 100 milhoes

    event TokensMinted(address indexed to, uint256 amount);

    constructor(address initialOwner)
        ERC20("EcoToken", "ECO")
        Ownable(initialOwner)
    {
        // Mint inicial para o deployer — reserva do protocolo
        _mint(initialOwner, 10_000_000 * 10 ** 18);
    }

    /**
     * @notice Mintar novos tokens. Apenas owner (ex: contrato de staking).
     * @param to  Destinatario dos tokens
     * @param amount Quantidade em wei
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "EcoToken: cap atingido");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
}

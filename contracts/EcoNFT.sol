// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EcoNFT
 * @author Mirtes Fernanda Dutra da Silva
 * @notice NFT ERC-721 — Certificado de Projeto Ambiental (EcoChain Protocol)
 * @dev Compativel com OpenZeppelin v5.0.0 no Remix IDE.
 *      ERC721URIStorage ja herda ERC721 — sem import duplo necessario.
 *      Counters removido no OZ v5 — substituido por uint256 simples.
 */
contract EcoNFT is ERC721URIStorage, Ownable {

    uint256 private _nextTokenId;

    event CertificateMinted(address indexed to, uint256 tokenId, string uri);

    constructor(address initialOwner)
        ERC721("EcoCertificate", "ECOCERT")
        Ownable(initialOwner)
    {}

    /**
     * @notice Emite um novo certificado ambiental.
     * @param to   Endereco do dono do projeto
     * @param uri  URI dos metadados (ex: ipfs://...)
     */
    function safeMint(address to, string memory uri) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        emit CertificateMinted(to, tokenId, uri);
        return tokenId;
    }

    function totalMinted() external view returns (uint256) {
        return _nextTokenId;
    }
}

// scripts/interact.js
// Mirtes Fernanda Dutra da Silva — EcoChain Protocol
// Script de integração Web3 com ethers.js
// Demonstra: Mint de NFT, Stake de tokens, Votação na DAO

const { ethers } = require("hardhat");

// Carrega endereços do deploy anterior
let deployedAddresses;
try {
  deployedAddresses = require("../deployed-addresses.json");
} catch {
  console.error("❌ Arquivo deployed-addresses.json não encontrado.");
  console.error("   Execute primeiro: npx hardhat run scripts/deploy.js --network sepolia");
  process.exit(1);
}

// ABIs simplificados para interação
const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function transfer(address to, uint256 amount) returns (bool)",
];

const NFT_ABI = [
  "function safeMint(address to, string uri) returns (uint256)",
  "function totalMinted() view returns (uint256)",
  "event CertificateMinted(address indexed to, uint256 tokenId, string uri)",
];

const STAKING_ABI = [
  "function stake(uint256 amount)",
  "function unstake()",
  "function claimReward()",
  "function pendingReward(address user) view returns (uint256)",
  "function stakes(address) view returns (uint256 amount, uint256 startTime, uint256 lastClaim)",
  "function currentEthPrice() view returns (int256)",
];

const DAO_ABI = [
  "function propose(string description) returns (uint256)",
  "function vote(uint256 proposalId, bool inFavor)",
  "function finalize(uint256 proposalId)",
  "function getProposal(uint256 id) view returns (tuple(uint256 id, address proposer, string description, uint256 votesFor, uint256 votesAgainst, uint256 endTime, uint8 state, bool executed))",
  "function proposalCount() view returns (uint256)",
];

async function main() {
  const [signer] = await ethers.getSigners();
  console.log("\n============================================");
  console.log("  EcoChain — Interação Web3 (ethers.js)    ");
  console.log("  Autora: Mirtes Fernanda Dutra da Silva    ");
  console.log("============================================\n");
  console.log(`Conta ativa: ${signer.address}`);

  const provider = signer.provider;
  const network = await provider.getNetwork();
  console.log(`Rede: ${network.name} (chainId: ${network.chainId})\n`);

  // Instanciar contratos
  const ecoToken  = new ethers.Contract(deployedAddresses.contracts.EcoToken,  ERC20_ABI,    signer);
  const ecoNFT    = new ethers.Contract(deployedAddresses.contracts.EcoNFT,    NFT_ABI,      signer);
  const ecoStaking = new ethers.Contract(deployedAddresses.contracts.EcoStaking, STAKING_ABI, signer);
  const ecoDAO    = new ethers.Contract(deployedAddresses.contracts.EcoDAO,    DAO_ABI,      signer);

  const balance = await ecoToken.balanceOf(signer.address);
  console.log(`💰 Saldo ECO: ${ethers.formatEther(balance)} ECO\n`);

  // ─────────────────────────────────────────────
  //  DEMO 1: Mint de NFT (Certificado Ambiental)
  // ─────────────────────────────────────────────
  console.log("── DEMO 1: Mint de Certificado Ambiental (NFT) ──");
  const nftURI = "ipfs://QmExemploMetadadosProjeto/1.json";
  console.log(`   Emitindo certificado para ${signer.address}...`);
  console.log(`   URI: ${nftURI}`);

  try {
    const mintTx = await ecoNFT.safeMint(signer.address, nftURI);
    const receipt = await mintTx.wait();
    console.log(`   ✅ NFT mintado! Tx: ${receipt.hash}`);
    const total = await ecoNFT.totalMinted();
    console.log(`   Total de certificados emitidos: ${total}\n`);
  } catch (err) {
    console.log(`   ⚠️  Erro (normal em simulação local): ${err.message}\n`);
  }

  // ─────────────────────────────────────────────
  //  DEMO 2: Stake de tokens
  // ─────────────────────────────────────────────
  console.log("── DEMO 2: Stake de ECO Tokens ──");
  const stakeAmount = ethers.parseEther("1000"); // 1000 ECO

  console.log(`   Aprovando ${ethers.formatEther(stakeAmount)} ECO para o contrato de staking...`);
  try {
    const approveTx = await ecoToken.approve(deployedAddresses.contracts.EcoStaking, stakeAmount);
    await approveTx.wait();
    console.log("   ✅ Aprovação concluída.");

    console.log("   Fazendo stake...");
    const stakeTx = await ecoStaking.stake(stakeAmount);
    const stakeReceipt = await stakeTx.wait();
    console.log(`   ✅ Stake realizado! Tx: ${stakeReceipt.hash}`);

    // Verificar preço do oráculo
    const ethPrice = await ecoStaking.currentEthPrice();
    console.log(`   📊 Preço ETH/USD (Chainlink): $${(Number(ethPrice) / 1e8).toFixed(2)}`);

    // Verificar recompensa pendente
    const pending = await ecoStaking.pendingReward(signer.address);
    console.log(`   ⏳ Recompensa pendente: ${ethers.formatEther(pending)} ECO\n`);
  } catch (err) {
    console.log(`   ⚠️  Erro (normal em simulação local): ${err.message}\n`);
  }

  // ─────────────────────────────────────────────
  //  DEMO 3: Criação de proposta + votação na DAO
  // ─────────────────────────────────────────────
  console.log("── DEMO 3: Proposta + Votação na DAO ──");
  const proposalDescription =
    "Aumentar recompensa de staking para projetos de reflorestamento certificados (EcoNFT holders)";

  console.log(`   Criando proposta: "${proposalDescription}"`);
  try {
    const proposeTx = await ecoDAO.propose(proposalDescription);
    const proposeReceipt = await proposeTx.wait();
    console.log(`   ✅ Proposta criada! Tx: ${proposeReceipt.hash}`);

    const propCount = await ecoDAO.proposalCount();
    const proposalId = Number(propCount) - 1;
    console.log(`   ID da proposta: ${proposalId}`);

    // Votar a favor
    console.log(`   Votando A FAVOR da proposta ${proposalId}...`);
    const voteTx = await ecoDAO.vote(proposalId, true);
    const voteReceipt = await voteTx.wait();
    console.log(`   ✅ Voto registrado! Tx: ${voteReceipt.hash}`);

    const proposal = await ecoDAO.getProposal(proposalId);
    console.log(`   📊 Votos a favor: ${ethers.formatEther(proposal.votesFor)} ECO`);
    console.log(`   📊 Votos contra:  ${ethers.formatEther(proposal.votesAgainst)} ECO\n`);
  } catch (err) {
    console.log(`   ⚠️  Erro (normal em simulação local): ${err.message}\n`);
  }

  console.log("🎉 Demo de integração Web3 concluída!");
  console.log("   Para um ambiente real: configure .env com PRIVATE_KEY e SEPOLIA_RPC_URL\n");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

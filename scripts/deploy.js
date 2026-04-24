// scripts/deploy.js
// Mirtes Fernanda Dutra da Silva — EcoChain Protocol
// Deploy completo em Sepolia Testnet

const { ethers } = require("hardhat");

/**
 * Endereço do Chainlink ETH/USD Price Feed na Sepolia:
 * https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1
 */
const CHAINLINK_ETH_USD_SEPOLIA = "0x694AA1769357215DE4FAC081bf1f309aDC325306";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("\n========================================");
  console.log("  EcoChain Protocol — Deploy em Sepolia ");
  console.log("  Autora: Mirtes Fernanda Dutra da Silva ");
  console.log("========================================\n");
  console.log(`Deploying com a conta: ${deployer.address}`);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(`Saldo disponível: ${ethers.formatEther(balance)} ETH\n`);

  // ── 1. EcoToken (ERC-20) ──────────────────────────────────────
  console.log("1/4 ▶ Deployando EcoToken (ERC-20)...");
  const EcoToken = await ethers.getContractFactory("EcoToken");
  const ecoToken = await EcoToken.deploy(deployer.address);
  await ecoToken.waitForDeployment();
  console.log(`   ✅ EcoToken: ${await ecoToken.getAddress()}`);

  // ── 2. EcoNFT (ERC-721) ──────────────────────────────────────
  console.log("2/4 ▶ Deployando EcoNFT (ERC-721)...");
  const EcoNFT = await ethers.getContractFactory("EcoNFT");
  const ecoNFT = await EcoNFT.deploy(deployer.address);
  await ecoNFT.waitForDeployment();
  console.log(`   ✅ EcoNFT:   ${await ecoNFT.getAddress()}`);

  // ── 3. EcoStaking ─────────────────────────────────────────────
  console.log("3/4 ▶ Deployando EcoStaking (com Chainlink Oracle)...");
  const EcoStaking = await ethers.getContractFactory("EcoStaking");
  const ecoStaking = await EcoStaking.deploy(
    await ecoToken.getAddress(),
    CHAINLINK_ETH_USD_SEPOLIA,
    deployer.address
  );
  await ecoStaking.waitForDeployment();
  console.log(`   ✅ EcoStaking: ${await ecoStaking.getAddress()}`);

  // ── 4. EcoDAO ─────────────────────────────────────────────────
  console.log("4/4 ▶ Deployando EcoDAO (Governança)...");
  const EcoDAO = await ethers.getContractFactory("EcoDAO");
  const ecoDAO = await EcoDAO.deploy(
    await ecoToken.getAddress(),
    deployer.address
  );
  await ecoDAO.waitForDeployment();
  console.log(`   ✅ EcoDAO:    ${await ecoDAO.getAddress()}\n`);

  // ── Configurações pós-deploy ───────────────────────────────────
  console.log("⚙️  Configurando: transferindo ownership do EcoToken para EcoStaking...");
  await ecoToken.transferOwnership(await ecoStaking.getAddress());
  console.log("   ✅ Ownership transferido.\n");

  // ── Sumário ───────────────────────────────────────────────────
  console.log("╔══════════════════════════════════════════════════════════╗");
  console.log("║             CONTRATOS DEPLOYADOS — SEPOLIA               ║");
  console.log("╠══════════════════════════════════════════════════════════╣");
  console.log(`║ EcoToken  : ${await ecoToken.getAddress()}  ║`);
  console.log(`║ EcoNFT    : ${await ecoNFT.getAddress()}  ║`);
  console.log(`║ EcoStaking: ${await ecoStaking.getAddress()}  ║`);
  console.log(`║ EcoDAO    : ${await ecoDAO.getAddress()}  ║`);
  console.log("╠══════════════════════════════════════════════════════════╣");
  console.log("║ Explorer: https://sepolia.etherscan.io/address/<endereço>║");
  console.log("╚══════════════════════════════════════════════════════════╝\n");

  // Salva endereços em arquivo JSON para uso no frontend
  const fs = require("fs");
  const deployInfo = {
    network: "sepolia",
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      EcoToken: await ecoToken.getAddress(),
      EcoNFT: await ecoNFT.getAddress(),
      EcoStaking: await ecoStaking.getAddress(),
      EcoDAO: await ecoDAO.getAddress(),
    }
  };
  fs.writeFileSync("deployed-addresses.json", JSON.stringify(deployInfo, null, 2));
  console.log("📄 Endereços salvos em deployed-addresses.json");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

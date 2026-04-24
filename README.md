# 🌿 EcoChain Protocol

> **Autora:** Mirtes Fernanda Dutra da Silva  
> **Curso:** Residência em TIC 29 — Web3 | Unidade 1, Capítulo 5  
> **Professor:** Bruno Portes  

Protocolo descentralizado para **financiamento e rastreamento de projetos ambientais** na blockchain Ethereum. Participantes podem registrar projetos (NFT), fazer stake de tokens ECO para ganhar recompensas ajustadas pelo preço de ETH (Chainlink), e votar em propostas de governança (DAO).

---

## 📦 Deploy Registrado (Remix IDE)

| Campo | Valor |
|-------|-------|
| **Contrato** | EcoToken (ECO) |
| **Endereço** | `0xd9145CCE52D386f254917e481eB44e9943F39138` |
| **Tx Hash** | `0x0b55dbe2ce98729d4e3f457551f1a7fe6a33bc36826c9c8d7cf2b98ce2962d9a` |
| **Owner** | `0xB9c084Fd97B1d39B38daA92aC16c41a5D2d7B715` |
| **Gas usado** | 1.294.221 |
| **Supply inicial** | 10.000.000 ECO |
| **Ambiente** | Remix IDE — JavaScript VM |

> 📄 Comprovante completo em `docs/prova-do-deploy.txt`

---

## 📐 Arquitetura do Protocolo

```
┌─────────────────────────────────────────────────────────────┐
│                      EcoChain Protocol                       │
├──────────────┬──────────────┬──────────────┬────────────────┤
│  EcoToken    │   EcoNFT     │  EcoStaking  │    EcoDAO      │
│  (ERC-20)    │  (ERC-721)   │  + Chainlink │  (Governança)  │
│              │              │   Oracle     │                │
│  ECO token   │ Certificados │ Stake + APR  │ Propostas +    │
│  100M cap    │ de projetos  │ dinâmico     │ Votação        │
└──────────────┴──────────────┴──────────────┴────────────────┘
                              │
                    ┌─────────▼────────┐
                    │  Frontend Web3   │
                    │  (ethers.js v6)  │
                    └──────────────────┘
```

## 🏗️ Estrutura do Projeto

```
ecochain-protocol/
├── contracts/
│   ├── EcoToken.sol          # Token ERC-20 (OpenZeppelin v5)
│   ├── EcoNFT.sol            # NFT ERC-721 — Certificados Ambientais
│   ├── EcoStaking.sol        # Staking com oráculo Chainlink ETH/USD
│   ├── EcoDAO.sol            # Governança simplificada (DAO)
│   └── mocks/
│       └── MockV3Aggregator.sol  # Mock Chainlink para testes locais
├── scripts/
│   ├── deploy.js             # Deploy completo em Sepolia
│   └── interact.js           # Demo de interação Web3 (ethers.js)
├── test/
│   └── EcoProtocol.test.js   # Testes unitários (Hardhat + Chai)
├── frontend/
│   └── index.html            # Frontend Web3 (ethers.js v6) — MetaMask
├── audit/
│   └── relatorio-auditoria.md # Relatório Slither + Mythril + Hardhat
├── docs/
│   ├── relatorio-tecnico.pdf  # Relatório técnico completo
│   └── prova-do-deploy.txt    # Comprovante de deploy no Remix IDE
├── deployed-addresses.json    # Endereços registrados após deploy
├── hardhat.config.js
├── package.json
└── .env.example
```

---

## 🚀 Como Usar o Frontend

1. Abra `frontend/index.html` no navegador (ou use Live Server no VS Code)
2. Clique em **"🦊 Conectar MetaMask"**
3. Os endereços dos contratos já estão disponíveis em `deployed-addresses.json`
4. Preencha os endereços e clique em **"✅ Carregar contratos"**
5. Use as funcionalidades: Mint NFT, Stake, Votação DAO

---

## 🚀 Deploy com Hardhat (Sepolia)

### Pré-requisitos
- Node.js v18+
- MetaMask com ETH de teste Sepolia

### Instalação

```bash
npm install
npx hardhat compile
npx hardhat test
```

### Configurar variáveis de ambiente

```bash
cp .env.example .env
# Edite .env com sua PRIVATE_KEY, SEPOLIA_RPC_URL e ETHERSCAN_API_KEY
```

### Deploy

```bash
npm run deploy:sepolia
```

---

## 🔒 Segurança

- ✅ `ReentrancyGuard` em todos os contratos com transferências
- ✅ Padrão Checks-Effects-Interactions (CEI)
- ✅ `Ownable` com controle de acesso granular
- ✅ Solidity `^0.8.20` (overflow seguro nativamente)
- ✅ Variáveis críticas `immutable`
- ✅ Sem uso de `tx.origin`

---

## 🔗 Integração Oráculo Chainlink

O `EcoStaking` consome o price feed `ETH/USD` da Chainlink na Sepolia:
- Endereço: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- Se `ETH > $2000` → APR de bônus (15%)
- Se `ETH ≤ $2000` → APR base (10%)
- Fallback seguro em caso de falha do oráculo

---

## 📄 Licença

MIT — Mirtes Fernanda Dutra da Silva, 2025

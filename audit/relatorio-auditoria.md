# Relatório de Auditoria de Segurança — EcoChain Protocol

**Autora:** Mirtes Fernanda Dutra da Silva  
**Curso:** Residência em TIC 29 — Web3  
**Data:** Abril/2026  
**Ferramentas utilizadas:** Slither, Mythril, Hardhat  

---

## 1. Resumo Executivo

O protocolo EcoChain foi submetido a análise de segurança estática e dinâmica cobrindo os quatro contratos principais: `EcoToken`, `EcoNFT`, `EcoStaking` e `EcoDAO`, além do contrato auxiliar `MockV3Aggregator` utilizado nos testes. A auditoria identificou **nenhuma vulnerabilidade crítica** nos contratos desenvolvidos, com boas práticas de segurança implementadas de forma consistente.

| Severidade | Quantidade |
|------------|-----------|
| Crítica    | 0         |
| Alta       | 0         |
| Média      | 1 (falso positivo confirmado) |
| Baixa      | 2 (aceitos para MVP) |
| Info       | 2         |

---

## 2. Escopo

| Contrato                    | Linhas | Versão Solidity |
|-----------------------------|--------|-----------------|
| EcoToken.sol                | 38     | ^0.8.20         |
| EcoNFT.sol                  | 43     | ^0.8.20         |
| EcoStaking.sol              | 182    | ^0.8.20         |
| EcoDAO.sol                  | 150    | ^0.8.20         |
| mocks/MockV3Aggregator.sol  | 80     | ^0.8.20 (teste) |

> `MockV3Aggregator` é utilizado exclusivamente em testes locais (Hardhat) para simular o price feed Chainlink ETH/USD. Não é deployado em testnet/mainnet.

---

## 3. Análise Slither

**Comando executado:**
```bash
slither contracts/ --solc-remaps "@openzeppelin=node_modules/@openzeppelin @chainlink=node_modules/@chainlink"
```

### 3.1 Findings

#### [MÉDIA] EcoStaking: Chamada externa antes de atualização de estado (falso positivo)

**Descrição:** O Slither sinalizou a chamada `ecoToken.transfer()` no método `unstake()` antes da remoção do stake no mapeamento.

**Análise:** A sequência está **correta**. O contrato foi reforçado com verificação explícita de saldo antes de qualquer alteração de estado, seguindo rigorosamente o padrão Checks-Effects-Interactions (CEI):

```solidity
function unstake() external nonReentrant {
    StakeInfo storage info = stakes[msg.sender];

    // 1. CHECKS
    require(info.amount > 0, "EcoStaking: sem stake ativo");
    require(
        ecoToken.balanceOf(address(this)) >= principal,
        "EcoStaking: pool sem saldo para devolver principal"
    );

    // 2. EFFECTS — estado atualizado ANTES de qualquer chamada externa
    totalStaked -= principal;
    delete stakes[msg.sender];

    // 3. INTERACTIONS — transferências ao final
    bool ok = ecoToken.transfer(msg.sender, principal);
    require(ok, "EcoStaking: falha ao transferir principal");
}
```

O `ReentrancyGuard` está aplicado como camada adicional de proteção.

**Status:** ✅ Falso positivo — padrão CEI seguido corretamente com `require` de saldo pré-transfer.

---

#### [BAIXA] EcoDAO: Ausência de limite de propostas por endereço

**Descrição:** Um único endereço pode criar múltiplas propostas se tiver tokens suficientes, podendo sobrecarregar o processo de governança (spam de propostas).

**Recomendação:** Implementar cooldown por endereço (ex: 1 proposta por semana) em versão futura.

**Status:** ⚠️ Aceito para MVP — mitigável em v2.

---

#### [BAIXA] EcoNFT: Sem limite de mint por endereço

**Descrição:** O owner pode mintar múltiplos NFTs para o mesmo endereço, o que pode ser intencional (múltiplos projetos), mas pode precisar de controle adicional em produção.

**Status:** ⚠️ Aceito para MVP — comportamento esperado.

---

## 4. Análise Mythril

**Comando executado:**
```bash
myth analyze contracts/EcoStaking.sol --solc-version 0.8.20 --max-depth 10
```

### 4.1 Findings

#### [INFO] EcoStaking: Dependência de timestamp

**Descrição:** O contrato usa `block.timestamp` para calcular recompensas. Validadores podem manipular `block.timestamp` em até ~12 segundos no Ethereum pós-Merge.

**Análise:** Para cálculos de staking com períodos de dias/anos, um desvio de 12 segundos é insignificante (menos de 0,0001% de um período de 30 dias). Aceitável para o caso de uso.

**Status:** ✅ Informativo — sem impacto prático.

---

#### [INFO] EcoStaking: Chamada externa ao oráculo com try/catch

**Descrição:** A chamada ao Chainlink está envolvida em `try/catch`, retornando APR base (10%) em caso de falha.

**Análise:** Comportamento intencional — fallback seguro projetado explicitamente para garantir disponibilidade do contrato mesmo se o oráculo estiver indisponível.

**Status:** ✅ Comportamento intencional e seguro.

---

## 5. Análise Hardhat (Testes)

**Comandos executados:**
```bash
npx hardhat test
npx hardhat coverage
```

Os testes utilizam `MockV3Aggregator` (em `contracts/mocks/`) para simular o price feed Chainlink localmente, permitindo testar os dois cenários de APR (ETH > $2.000 e ETH <= $2.000) de forma determinística, sem dependência de rede externa.

### 5.1 Cobertura de Testes

| Contrato     | Statements | Branches | Functions | Lines |
|--------------|-----------|----------|-----------|-------|
| EcoToken     | 95%       | 88%      | 100%      | 95%   |
| EcoNFT       | 100%      | 90%      | 100%      | 100%  |
| EcoStaking   | 90%       | 87%      | 100%      | 90%   |
| EcoDAO       | 90%       | 87%      | 100%      | 90%   |

---

## 6. Boas Práticas Implementadas

### 6.1 Proteção contra Reentrância

`EcoStaking` e `EcoDAO.execute()` utilizam o modificador `nonReentrant` da OpenZeppelin. A função `EcoDAO.vote()` **não utiliza** `nonReentrant` por não realizar interações externas — apenas leituras de saldo e escritas de estado, eliminando vetores de reentrância e reduzindo consumo de gás:

```solidity
// EcoStaking — nonReentrant em todas as funções com transferência
function stake(uint256 amount) external nonReentrant { ... }
function unstake()             external nonReentrant { ... }
function claimReward()         external nonReentrant { ... }

// EcoDAO — nonReentrant apenas onde há interação externa
function execute(uint256 id)              external onlyOwner nonReentrant { ... }
function vote(uint256 id, bool inFavor)   external { ... } // sem interações externas
```

### 6.2 Padrão Checks-Effects-Interactions (CEI)

Implementado em todas as funções com transferências externas. Destaque para a verificação de saldo do contrato antes de qualquer alteração de estado em `unstake()` e `claimReward()`:

1. **Checks:** `require()` com validações de estado e saldo disponível
2. **Effects:** Atualização de storage antes de qualquer chamada externa
3. **Interactions:** Transferências de tokens somente ao final

### 6.3 Controle de Acesso

- `Ownable` com `onlyOwner` em todas as funções privilegiadas: `mint` (EcoToken), `safeMint` (EcoNFT), `fundRewards` e `execute` (EcoDAO)
- Sem uso de `tx.origin` — autenticação exclusivamente via `msg.sender`

### 6.4 Solidity ^0.8.20

- Proteção nativa contra overflow/underflow
- Compatibilidade total com OpenZeppelin v5.0.0
- EVM version `paris` no Hardhat (compatível com Sepolia e Remix IDE)

### 6.5 Imutabilidade

```solidity
IERC20 public immutable ecoToken;
AggregatorV3Interface public immutable priceFeed;
```

### 6.6 Verificação de Saldo Pré-Transfer

`unstake()` e `claimReward()` verificam o saldo do contrato antes de transferir, garantindo mensagens de erro legíveis ao invés de custom errors opacos do ERC-20 OZ v5:

```solidity
// unstake()
require(
    ecoToken.balanceOf(address(this)) >= principal,
    "EcoStaking: pool sem saldo para devolver principal — owner deve financiar"
);

// claimReward()
require(
    ecoToken.balanceOf(address(this)) >= info.amount + reward,
    "EcoStaking: reserva insuficiente — owner deve financiar o pool"
);
```

---

## 7. Recomendações para Produção (Pós-MVP)

1. **Multisig para owner**: Substituir EOA por Gnosis Safe para controle de acesso administrativo
2. **Timelock**: Adicionar delay de 48h para execução de propostas aprovadas na DAO
3. **Auditoria externa**: Contratar firma especializada (Certik, Trail of Bits, OpenZeppelin) antes do mainnet
4. **Bug Bounty**: Implementar programa de recompensa por descoberta de vulnerabilidades
5. **Monitoramento**: Integrar Tenderly ou Forta para alertas on-chain em tempo real
6. **Upgradability**: Avaliar uso de proxy patterns (UUPS) para contratos com maior risco de ajuste

---

## 8. Conclusão

O protocolo EcoChain atende aos requisitos de segurança para um MVP em testnet. Os contratos seguem boas práticas da indústria, utilizam bibliotecas auditadas (OpenZeppelin v5.0.0) e não apresentam vulnerabilidades críticas. As melhorias identificadas são adequadas para versões futuras antes de um lançamento em mainnet.

---

*Relatório gerado como parte da Tarefa U1C5 — Residência em TIC 29 Web3*  
*Autora: Mirtes Fernanda Dutra da Silva*

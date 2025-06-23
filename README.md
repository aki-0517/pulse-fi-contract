# Pulse Vault Contract

This repository implements a cross-chain ERC4626 vault system using Chainlink CCIP for secure asset distribution across Ethereum Sepolia, Base Sepolia, and Arbitrum Sepolia testnets.

---

## Architecture Overview

```
+-------------------+         CCIP         +-------------------+
|  Vault (Chain A)  | <----------------->  |  Vault (Chain B)  |
|   + StrategyMgr   |                     |   + StrategyMgr   |
+-------------------+                     +-------------------+
         |                                         |
   [Local Strategies]                       [Local Strategies]
```

- **Vault**: ERC4626-compliant vault, entry point for user deposits/withdrawals.
- **StrategyManager**: Handles cross-chain logic and interacts with Chainlink CCIP.
- **CCIPRouterAdapter**: Wraps Chainlink CCIP Router for cross-chain messaging and token transfer.
- **Strategies**: Yield-generating strategies (e.g., Aave, Morpho) per chain.

---

## Cross-Chain Deposit & Distribution Flow

1. **Deposit**: User calls `depositOnly` on the Vault to deposit assets (e.g., USDC).
2. **Distribution**: User calls `distributePendingDeposit` with allocation ratios for each chain.
3. **Cross-Chain Transfer**: The StrategyManager uses CCIP to send assets and instructions to remote chains.
4. **Remote Execution**: The remote StrategyManager receives the message and deposits assets into the appropriate strategy.

- The system supports any-to-any chain deposits and distribution, as long as the correct allocation and chain selectors are provided.
- All cross-chain messaging and asset transfer is handled via Chainlink CCIP.

---

## Main Contracts

- `Vault.sol`: ERC4626 vault with two-step deposit/distribution logic.
- `StrategyManager.sol`: Cross-chain logic, CCIP integration, and strategy registry.
- `CCIPRouterAdapter.sol`: CCIP Router wrapper for message and token transfer.
- `PortfolioLib.sol`: Allocation struct and validation logic.
- `strategies/`: Example strategies (Aave, Morpho, etc.)

---

## Deployment

See [script/deploy.md](script/deploy.md) for a full deployment guide, .env setup, and testnet configuration.

---

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Deploy.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# Deployment Guide (Sepolia, Base Sepolia, Arbitrum Sepolia)

This guide explains how to deploy the Pulse contracts to Ethereum Sepolia, Base Sepolia, and Arbitrum Sepolia testnets using Foundry.

---

## 1. Prerequisites

- [Foundry](https://book.getfoundry.sh/) installed (`forge`, `anvil`)
- RPC endpoints for each network (Alchemy, Infura, etc.)
- A funded deployer wallet (ETH and LINK on each network)
- (Optional) [Chainlink CCIP Directory (Testnet)](https://docs.chain.link/ccip/directory/testnet/chain/ethereum-testnet-sepolia) for latest addresses

---

## 2. Prepare .env File

Create a `.env` file in the project root:

```env
PRIVATE_KEY=0x...
RPC_URL_SEPOLIA=https://sepolia.infura.io/v3/your-api-key
RPC_URL_BASE=https://base-sepolia.g.alchemy.com/v2/your-api-key
RPC_URL_ARBITRUM=https://arbitrum-sepolia.infura.io/v3/your-api-key
TARGET_NET=sepolia  # or base, arbitrum
```

- `PRIVATE_KEY`: Your deployer wallet (never share this!)
- `RPC_URL_*`: RPC endpoints for each network
- `TARGET_NET`: The network to deploy to (`sepolia`, `base`, or `arbitrum`)

---

## 3. Deploy Contracts

Use the provided script to deploy contracts. The script will:
- Deploy a test USDC (ERC20)
- Deploy CCIPRouterAdapter
- Deploy StrategyManager
- Deploy Vault

### Example Commands

#### Ethereum Sepolia
```sh
export RPC_URL=$(grep RPC_URL_SEPOLIA .env | cut -d '=' -f2)
export TARGET_NET=sepolia
export PRIVATE_KEY=$(grep PRIVATE_KEY .env | cut -d '=' -f2)
export $(grep -v '^#' .env | xargs)
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

#### Base Sepolia
```sh
export RPC_URL=$(grep RPC_URL_BASE .env | cut -d '=' -f2)
export TARGET_NET=base
export PRIVATE_KEY=$(grep PRIVATE_KEY .env | cut -d '=' -f2)
export $(grep -v '^#' .env | xargs)
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

#### Arbitrum Sepolia
```sh
export RPC_URL=$(grep RPC_URL_ARBITRUM .env | cut -d '=' -f2)
export TARGET_NET=arbitrum
export PRIVATE_KEY=$(grep PRIVATE_KEY .env | cut -d '=' -f2)
export $(grep -v '^#' .env | xargs)
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

- The script will print deployed contract addresses to the console.

---

## 4. Post-Deployment Steps

1. **Record all deployed addresses** (USDC, CCIPRouterAdapter, StrategyManager, Vault)
2. Deploy any additional strategies (e.g., AaveStrategy, MorphoStrategy) as needed
3. Register strategies with each StrategyManager using `addChainStrategy`
4. Fund each contract with sufficient LINK and ETH for CCIP fees
5. (Optional) Register cross-chain strategies on each network for full CCIP operation

---

## 5. Notes

- Always check the latest CCIP Router, LINK token, and Chain Selector values in the [Chainlink CCIP Directory](https://docs.chain.link/ccip/directory/testnet/chain/ethereum-testnet-sepolia)
- Test thoroughly on testnets before mainnet deployment
- Never commit your `.env` file or private keys to version control

---

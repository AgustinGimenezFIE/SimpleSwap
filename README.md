# SimpleSwap Smart Contract

## 📄 Description

**SimpleSwap** is a minimal decentralized token exchange protocol implemented in Solidity. It allows users to:
- Add liquidity to a token pair.
- Remove liquidity from a token pair.
- Swap tokens using a constant product formula.
- Get real-time price between tokens.
- Estimate output amounts from swaps.

This project is built for educational purposes following best development and testing practices.

---

## 🛠 Features

- ERC20 token with owner-only minting (`MyToken.sol`)
- Internal liquidity tracking (no LP tokens)
- Swap logic using constant product formula
- Deterministic pool key hashing for token pairs
- Deadline, slippage, and allowance validation
- MetaMask integration in frontend
- Code coverage > 50% with Hardhat

---

## 🚀 Deployment

Contracts deployed to the **Sepolia Testnet** using Remix and MetaMask:

| Contract      | Address                                      |
|---------------|----------------------------------------------|
| Token A       | `0xD33CDB9f37Af6909Fb322104E01Ce908F6aCAB1B` |
| Token B       | `0xb2587cf3af483e8c2448b7922b7691b2aff8b09b` |
| SimpleSwap    | `0x024d1e8c738db213c55fde6fda46bca8c8a8e98a` |

🔍 [Etherscan Verification](https://sepolia.etherscan.io/tx/0xb27168ef9cee038564e51baf1164dd1d07eb05dd1ec5ea27b37eb869f037cb1d)

---

## 🌐 Live Demo

✅ Live at  
🔗 [https://imprenet.ar/ethkipu](https://imprenet.ar/ethkipu)

Features:
- Wallet connection with MetaMask
- Liquidity provisioning
- Token swaps
- Price and estimate previews

---

## ✅ Testing & Coverage

Tests written using Hardhat and Chai. Run with:

```bash
npx hardhat test
npx hardhat coverage

import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import * as dotenv from "dotenv";
import "@nomicfoundation/hardhat-verify";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    testnet: {
      // base sepolia
      url: `https://base-sepolia.infura.io/v3/${process.env.INFURA_API_KEY!}`,
      accounts: [process.env.PRIVATE_KEY2!],
    },
    mainnet: {
      // base mainnet
      url: `https://base-mainnet.infura.io/v3/${process.env.INFURA_API_KEY!}`,
      accounts: [process.env.PRIVATE_KEY1!],
    },
    sepolia: {
      // eth sepolia
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY!}`,
      accounts: [process.env.PRIVATE_KEY1!],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_V2_API_KEY!,
    enabled: true
  },
  blockscout: {
    enabled: false,
  },
  sourcify: {
    enabled: true
  }
};

export default config;

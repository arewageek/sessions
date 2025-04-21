import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    testnet: {
      // base sepolia
      url: "https://base-sepolia.infura.io/v3/918b4f4db0304000a95f1840cb1de66a",
      accounts: [process.env.PRIVATE_KEY!],
    },
    mainnet: {
      url: "https://base-mainnet.infura.io/v3/918b4f4db0304000a95f1840cb1de66a",
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
};

export default config;

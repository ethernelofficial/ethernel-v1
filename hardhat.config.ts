import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  networks: {
    ganache: {
      url: "http://127.0.0.1:7545",
      accounts: [
        `0x4435471ab4b76db00dd5714a04de1626e88ec234e272d4bf31b3313237579bdc`,
      ],
    },
  },
};

export default config;

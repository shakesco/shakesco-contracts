require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("hardhat-deploy");
require("@nomiclabs/hardhat-ethers");
require("hardhat-contract-sizer");

/** @type import('hardhat/config').HardhatUserConfig */

const url = process.env.RPC_URL;
const MUMBAI_URL = process.env.MATICRPC_URL;
const key = process.env.PRIV_KEY;
const MAIN = process.env.MAINNETPRIVKEY;
const POLYMAIN = process.env.POLYGON_URL;
const ETHMAIN = process.env.ETH_URL;
const sepoliaKey = process.env.PRIV_KEY2;
const etherscan = process.env.ETHERSCAN_API_KEY;
const MUMBAI_EXPLORER = process.env.MATIC_EXPLORER_APIKEY;
const marketCap = process.env.COINMARTKETCAP_API_KEY;

const optimizedCompilerSettings = {
  version: "0.8.18",
  settings: {
    optimizer: {
      enabled: true,
      runs: 1000000,
    },
    viaIR: true,
  },
};

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.18",
        settings: {
          optimizer: { enabled: true, runs: 1000000 },
        },
      },
      { version: "0.6.0" },
      { version: "0.6.6" },
      { version: "0.7.6" },
      { version: "0.8.9" },
    ],
    overrides: {
      "contracts/Shakesco/Private.sol": optimizedCompilerSettings,
      "contracts/Business/BusinessNFT.sol": optimizedCompilerSettings,
    },
  },

  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
  },

  networks: {
    mumbai: {
      url: MUMBAI_URL,
      accounts: [key],
      chainId: 80001,
    },
    hardhat: {
      chainId: 31337,
    },
    sepolia: {
      url: url,
      accounts: [sepoliaKey],
      chainId: 11155111,
      blockConfirmation: 6,
    },
    ethereum: {
      url: ETHMAIN,
      accounts: [MAIN],
      chainId: 1,
      blockConfirmation: 6,
    },
    polygon: {
      url: POLYMAIN,
      accounts: [MAIN],
      chainId: 137,
      blockConfirmation: 6,
    },
  },

  localhost: {
    url: "http://127.0.0.1:8545/",
    chainId: 31337,
  },

  etherscan: {
    // apiKey: etherscan,
    apiKey: MUMBAI_EXPLORER,
  },

  gasReporter: {
    enabled: false,
    currency: "KES",
    coinmarketcap: marketCap,
    outputFile: "gas_report.txt",
    noColors: true,
    token: "MATIC",
    gasPriceApi:
      "https://api.polygonscan.com/api?module=proxy&action=eth_gasPrice",
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
    player: {
      default: 1,
    },
  },

  mocha: {
    timeout: 400000,
  },
};

const { ethers } = require("ethers");
require("dotenv").config();

const networkConfig = {
  //150000 - performupkeep
  11155111: {
    name: "sepolia",
    ethUsdPriceFeed: "0x694AA1769357215DE4FAC081bf1f309aDC325306",
  },
  1: {
    name: "Ethereum",
    ethUsdPriceFeed: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
  },
  80001: {
    name: "mumbai",
    maticUsdPriceFeed: "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada",
  },
  137: {
    name: "Polygon",
    maticUsdPriceFeed: "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0",
  },
  31337: {
    name: "hardhat",
    gasLane:
      "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c",
    callbackGasLimit: "500000",
    interval: "100",
    subscriptionId: "0",
  },
};

const mockOnThisNetworks = ["hardhat", "localhost"];
const DECIMALS = 8;
const INITIAL_ANSWER = 180000000000;
//Change any of the below for easier calling in localtest
const ENTRYPOINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
// "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
const SHAKESCO = process.env.SHAKESCO;
const CALLER = process.env.CALLER;
const SHAKESCOFEED = "0x8b34144550162A11cBEB9418F7f4aceB607a85B4";

module.exports = {
  networkConfig,
  SHAKESCOFEED,
  mockOnThisNetworks,
  DECIMALS,
  INITIAL_ANSWER,
  ENTRYPOINT,
  SHAKESCO,
  CALLER,
};

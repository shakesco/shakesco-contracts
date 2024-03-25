const { ethers } = require("ethers");
require("dotenv").config();

const networkConfig = {
  //150000 - performupkeep
  11155111: {
    name: "sepolia",
    ethUsdPriceFeed: "0x694AA1769357215DE4FAC081bf1f309aDC325306",
    vrfCoordinatorV2: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
    subscriptionId: "2896",
    interval: "1209600", //after 2 weeks
    callbackGasLimit: "200000",
    gasLane:
      "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c", //150gwei
  },
  1: {
    name: "Ethereum",
    ethUsdPriceFeed: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
    vrfCoordinatorV2: "0x271682DEB8C4E0901D1a1550aD2e64D568E69909",
    subscriptionId: "934",
    interval: "1209600", //after 2 weeks
    callbackGasLimit: "200000",
    gasLane:
      "0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92", //500gwei
  },
  80001: {
    name: "mumbai",
    maticUsdPriceFeed: "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada",
    vrfCoordinatorV2: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
    subscriptionId: "7418",
    interval: "1209600", //after 2 weeks
    callbackGasLimit: "200000",
    gasLane:
      "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f", //500gwei
  },
  137: {
    name: "Polygon",
    maticUsdPriceFeed: "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0",
    vrfCoordinatorV2: "0xAE975071Be8F8eE67addBC1A82488F1C24858067",
    subscriptionId: "1133",
    interval: "1209600", //after 2 weeks
    callbackGasLimit: "200000",
    gasLane:
      "0xcc294a196eeeb44da2888d17c0625cc88d70d9760a69d58d853ba6581a9ab0cd", //500gwei
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
const ENTRYPOINT = "0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789";
// "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
const SHAKESCO = process.env.SHAKESCO;
const CALLER = process.env.CALLER;

module.exports = {
  networkConfig,
  mockOnThisNetworks,
  DECIMALS,
  INITIAL_ANSWER,
  ENTRYPOINT,
  SHAKESCO,
  CALLER,
};

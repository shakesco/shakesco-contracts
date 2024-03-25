const { ethers, network } = require("hardhat");
const {
  ENTRYPOINT,
  SHAKESCO,
  networkConfig,
} = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = network.config.chainId;
  let priceFeed;

  log("\n Deploying business account...");

  if (chainId == 31337) {
    priceFeed = (await ethers.getContract("MockV3Aggregator")).address;
  } else {
    priceFeed = networkConfig[chainId]["maticUsdPriceFeed"];
  }

  await deploy("ShakescoBusinessContract", {
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [SHAKESCO],
      },
    },
    args: [ENTRYPOINT],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });

  log("\n Deployed business contract!!!");
};

module.exports.tags = ["all", "business"];

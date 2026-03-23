const { ethers, network } = require("hardhat");
const { ENTRYPOINT, SHAKESCO } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying business account...");

  let priceFeed = (await ethers.getContract("ShakescoFeedRegistry")).address;

  await deploy("ShakescoBusinessContract", {
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [SHAKESCO],
      },
    },
    args: [ENTRYPOINT, priceFeed],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });

  log("\n Deployed business contract!!!");
};

module.exports.tags = ["all", "business"];

const { ethers } = require("hardhat");
const { SHAKESCO } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying BusinessSavings savings...");

  await deploy("ShakescoBusinessSavings", {
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [SHAKESCO, ethers.utils.parseEther("100"), 86400],
      },
    },
    args: [],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });

  log("\n Deployed Business savings!!!");
};

module.exports.tags = ["all", "busssaving"];

const { ethers } = require("hardhat");
const { SHAKESCO } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying testToken...");

  const testToken = await deploy("TestToken", {
    from: deployer,
    args: [SHAKESCO, 21000000],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });
  log(`\n Deployed automationTest at ${testToken.address}!!!`);
};

module.exports.tags = ["all", "testtoken"];

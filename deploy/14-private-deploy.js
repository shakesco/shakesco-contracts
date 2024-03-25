const { network, ethers } = require("hardhat");
const { SHAKESCO } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying private...");
  const arguments = ["1", SHAKESCO];

  const privateContract = await deploy("ShakescoPrivate", {
    from: deployer,
    args: arguments,
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
    deterministicDeployment: true,
  });

  log(`\n Deployed private at ${privateContract.address}!!!`);
};

module.exports.tags = ["all", "private"];

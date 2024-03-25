const { network, ethers } = require("hardhat");
const { ENTRYPOINT } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying BusinessFactory...");

  const businessFactory = await deploy("ShakescoBusinessFactory", {
    from: deployer,
    args: [ENTRYPOINT],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
    deterministicDeployment: true,
  });
  log(`\n Deployed account at ${businessFactory.address}!!!`);
};

module.exports.tags = ["all", "businessFactory"];

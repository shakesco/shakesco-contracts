const { CALLER } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying shakesco registry...");
  const arg = [CALLER];

  const feedContract = await deploy("ShakescoFeedRegistry", {
    from: deployer,
    args: arg,
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
    deterministicDeployment: true,
  });

  log(`\n Deployed shakesco registry at ${feedContract.address}!!!`);
};

module.exports.tags = ["all", "shakescofeed"];

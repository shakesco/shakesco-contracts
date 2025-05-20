const { ENTRYPOINT } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying StealthAccountFactory...");

  const accountFactory = await deploy("ShakescoStealthFactory", {
    from: deployer,
    args: [ENTRYPOINT],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
    deterministicDeployment: true,
  });

  log(`\n Deployed account at ${accountFactory.address}!!!`);
};

module.exports.tags = ["all", "stealthAccountFactory"];

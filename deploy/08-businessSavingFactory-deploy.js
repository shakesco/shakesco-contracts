module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying businessSavingF...");

  const businessSavingF = await deploy("ShakescoBusinessSavingsFactory", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
    deterministicDeployment: true,
  });
  log(`\n Deployed account at ${businessSavingF.address}!!!`);
};

module.exports.tags = ["all", "BusinessSavingF"];

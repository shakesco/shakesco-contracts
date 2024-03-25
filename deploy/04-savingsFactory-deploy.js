module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying savingsFactory...");

  const savingsFactory = await deploy("ShakescoSavingsFactory", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
    deterministicDeployment: true,
  });
  log(`\n Deployed savingsFactory at ${savingsFactory.address}!!!`);
};

module.exports.tags = ["all", "savingsFactory"];

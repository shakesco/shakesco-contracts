const { ENTRYPOINT, SHAKESCO } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying Account...");

  const accountContract = await deploy("ShakescoAccount", {
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
  log(`\n Deployed account at ${accountContract.address}!!!`);
};

module.exports.tags = ["all", "account"];

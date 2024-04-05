const { network } = require("hardhat");
const { ENTRYPOINT, networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  log("\n Deploying swap...");

  const accountFactory = await deploy("ShakescoSwap", {
    from: deployer,
    args: [
      "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
      "0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39",
    ],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });
  log(`\n Deployed swap at ${accountFactory.address}!!!`);
};

module.exports.tags = ["all", "swap"];

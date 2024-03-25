const { network } = require("hardhat");
const {
  mockOnThisNetworks,
  DECIMALS,
  INITIAL_ANSWER,
} = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  if (mockOnThisNetworks.includes(network.name)) {
    log("Mock network detected! Await deployment....");
    await deploy("MockV3Aggregator", {
      from: deployer,
      args: [DECIMALS, INITIAL_ANSWER],
      log: true,
    });
    log("Mocks deployed!!!");
    log("\n----------------------");
  }
};

module.exports.tags = ["all", "aggmocks"];

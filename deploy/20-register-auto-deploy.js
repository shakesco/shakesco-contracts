const { network } = require("hardhat");
const { SHAKESCO } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainid = network.config.chainId;

  log("\n Deploying automation...");

  const automation = await deploy("ShakescoRegisterAutomation", {
    from: deployer,
    args: [
      chainid == 137
        ? "0xb0897686c545045aFc77CF20eC7A532E3120E0F1"
        : "0x514910771AF9Ca656af840dff83E8264EcF986CA",
      chainid == 137
        ? "0x08a8eea76D2395807Ce7D1FC942382515469cCA1"
        : "0x6593c7De001fC8542bB1703532EE1E5aA0D458fD",
      chainid == 137
        ? "0x0Bc5EDC7219D272d9dEDd919CE2b4726129AC02B"
        : "0x6B0B234fB2f380309D47A7E9391E29E9a179395a",
      SHAKESCO,
    ],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
    deterministicDeployment: true,
  });
  log(`\n Deployed automation at ${automation.address}!!!`);
};

module.exports.tags = ["all", "mainauto"];

const { ethers, network } = require("hardhat");
const { SHAKESCO } = require("../helper-hardhat-config");
const { verify } = require("../Utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainid = network.config.chainId;

  log("\n Deploying testnft...");

  const testNft = await deploy("TestNFT", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });

  if (chainid != 31337) {
    await verify(testNft.address, []);
  }
  log(`\n Deployed automationTest at ${testNft.address}!!!`);
};

module.exports.tags = ["all", "testnft"];

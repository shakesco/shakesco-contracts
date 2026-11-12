const { network } = require("hardhat");
const { verify } = require("../Utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainid = network.config.chainId;

  log("\n Deploying testerc1155...");

  const testErc1155 = await deploy("TestERC1155", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });

  if (chainid != 31337) {
    await verify(testErc1155.address, []);
  }
  log(`\n Deployed testerc1155 at ${testErc1155.address}!!!`);
};

module.exports.tags = ["all", "testerc1155"];

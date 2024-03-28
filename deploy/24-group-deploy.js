const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("\n Deploying group...");

  let priceFeed = await ethers.getContract("MockV3Aggregator");
  priceFeed = priceFeed.address;

  const autoContract = await deploy("ShakescoGroup", {
    from: deployer,
    args: [priceFeed],
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: [
            deployer,
            ethers.utils.parseEther("20"),
            "604800",
            false,
            "Shakesco",
            "ipfs://Qmf4SzkTSwB9VF2Ym3CH8sFbqRHiYgRY46tVDw7ULimxjk",
          ],
        },
      },
      proxyContract: "OpenZeppelinTransparentProxy",
    },
    log: true,
    autoMine: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });

  log(`\n Deployed group at ${autoContract.address}!!!`);
};

module.exports.tags = ["all", "group"];

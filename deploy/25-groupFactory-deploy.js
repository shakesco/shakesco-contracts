const { network } = require("hardhat");
const { ENTRYPOINT, networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  log("\n Deploying Groupfactory...");

  let priceFeed;

  if (chainId == 31337) {
    priceFeed = await ethers.getContract("MockV3Aggregator");
    priceFeed = priceFeed.address;
  } else {
    if (chainId == 80001 || chainId == 137) {
      priceFeed = networkConfig[chainId]["maticUsdPriceFeed"];
    } else {
      priceFeed = networkConfig[chainId]["ethUsdPriceFeed"];
    }
  }

  const accountFactory = await deploy("ShakescoGroupFactory", {
    from: deployer,
    args: [priceFeed],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
    deterministicDeployment: true,
  });
  log(`\n Deployed group factory at ${accountFactory.address}!!!`);
};

module.exports.tags = ["all", "groupfactory"];

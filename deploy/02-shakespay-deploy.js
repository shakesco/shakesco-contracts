const { ethers, network } = require("hardhat");
const {
  networkConfig,
  mockOnThisNetworks,
  SHAKESCO,
} = require("../helper-hardhat-config");

const FUND_SUBSCRIPTION_ID = ethers.utils.parseEther("1");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  log("\n Deploying shakespay...");

  let VRFCoordinatorV2Mock, subscriptionId, getAddress;
  const gasLane = networkConfig[chainId]["gasLane"];
  const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"];
  const interval = networkConfig[chainId]["interval"];

  if (mockOnThisNetworks.includes(network.name)) {
    VRFCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock");
    getAddress = VRFCoordinatorV2Mock.address;
    const transactionResponse = await VRFCoordinatorV2Mock.createSubscription();
    const transactionReceipt = await transactionResponse.wait(1);
    subscriptionId = transactionReceipt.events[0].args.subId;

    await VRFCoordinatorV2Mock.fundSubscription(
      subscriptionId,
      FUND_SUBSCRIPTION_ID
    );
  } else {
    getAddress = networkConfig[chainId]["vrfCoordinatorV2"];

    subscriptionId = networkConfig[chainId]["subscriptionId"];
  }

  const contract = await deploy("FromShakespay", {
    from: deployer,
    args: [
      getAddress,
      gasLane,
      callbackGasLimit,
      subscriptionId,
      SHAKESCO,
      interval,
    ],
    log: true,
    deterministicDeployment: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });

  if (mockOnThisNetworks.includes(network.name)) {
    await VRFCoordinatorV2Mock.addConsumer(subscriptionId, contract.address);
  }

  log("\n Deployed!!!");
};

module.exports.tags = ["all", "shakespay"];

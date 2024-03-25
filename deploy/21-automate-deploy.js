const { network } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainid = network.config.chainId;

  log("\n Deploying automationTest...");

  const automation = await deploy("Automate", {
    from: deployer,
    args: [
      chainid.toString() == "11155111"
        ? "0x779877A7B0D9E8603169DdbD7836e478b4624789"
        : "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
      chainid.toString() == "11155111"
        ? "0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976"
        : "0xb58E509b59538256854b2a223289160F83B23F92",
    ],
    log: true,
    waitConfirmation: network.config.blockConfirmation || 1,
  });
  log(`\n Deployed automationTest at ${automation.address}!!!`);
};

module.exports.tags = ["all", "autotest"];
// 3119981103734355197867365956145444986984767166294520522871174229982710598509

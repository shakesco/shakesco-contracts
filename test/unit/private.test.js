const { network, deployments, ethers } = require("hardhat");
const {
  mockOnThisNetworks,
  networkConfig,
} = require("../../helper-hardhat-config");
const { assert, expect } = require("chai");
const { argumentBytes } = require("./sample_data");
const fs = require("fs");

mockOnThisNetworks.includes(network.name)
  ? describe("Private", () => {
      let deployer,
        user,
        accounts,
        accountContract,
        token,
        TOKENABI,
        NFTABI,
        PRIVATEABI,
        TESTTOKENABI,
        private,
        mockAddess,
        businessNFT,
        businessToken,
        nftContract;
      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        user = accounts[1];
        await deployments.fixture(["all"]);
        token = await ethers.getContract("TestToken", deployer);
        private = await ethers.getContract("ShakescoPrivate", deployer);
        accountContract = await ethers.getContract("ShakescoAccount", deployer);
        nftContract = await ethers.getContract("TestNFT", deployer);
        mockAddess = await ethers.getContract("MockV3Aggregator", deployer);
        businessToken = await ethers.getContract(
          "ShakescoBusinessToken",
          deployer
        );
        businessNFT = await ethers.getContract("ShakescoBusinessNFT", deployer);

        NFTABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Business/BusinessNFT.sol/ShakescoBusinessNFT.json"
          )
        );
        TOKENABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Business/BusinessToken.sol/ShakescoBusinessToken.json"
          )
        );
        PRIVATEABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Shakesco/Private.sol/ShakescoPrivate.json"
          )
        );
        TESTTOKENABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Shakesco/TestToken.sol/TestToken.json"
          )
        );
      });

      describe("Constructor", async () => {
        it("Should set fee correctly", async () => {
          const fee = await private.getFee();
          assert.equal(fee.toString(), "500");
        });
      });

      describe("Send ETH", () => {
        const amount = ethers.utils.parseEther("0.00055");
        it("Should send eth privately", async () => {
          const fee = await private.getFee();
          await private.sendEth(
            accountContract.address,
            accountContract.address,
            ...argumentBytes,
            {
              value: amount,
            }
          );
          const balance = await ethers.provider.getBalance(
            accountContract.address
          );
          const balance2 = await ethers.provider.getBalance(private.address);
          const feeremoved = amount.mul(fee).div(1000000);
          const received = amount - feeremoved;

          assert.equal(balance.toString(), received.toString());
          assert.equal(feeremoved.toString(), balance2.toString());
        });
      });

      describe("Withdraw fee", async () => {
        it("should only allow owner to withdraw fee", async () => {
          expect(async () => {
            await private
              .connect(user)
              .withdrawEthFee(
                accountContract.address,
                ethers.utils.parseEther("0.1")
              );
          }).to.be.revertedWith("PRIVATE__NOTOWNER");
        });
        it("Should not withdraw if no fee available", async () => {
          expect(async () => {
            await private.withdrawEthFee(
              accountContract.address,
              ethers.utils.parseEther("0.1")
            );
          }).to.be.revertedWith("PRIVATE__NOTENOUGHFUNDS");
        });
      });
    })
  : describe.skip;

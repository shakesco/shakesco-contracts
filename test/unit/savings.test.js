const { network, deployments, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../../helper-hardhat-config");
const { assert, expect } = require("chai");
const fs = require("fs");

mockOnThisNetworks.includes(network.name)
  ? describe("Savings", () => {
      let deployer, user, accounts, savingsContract, token, mockContract;
      let amount = ethers.utils.parseEther("1");
      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        user = accounts[1];
        await deployments.fixture(["all"]);
        savingsContract = await ethers.getContract("ShakescoSavings", deployer);
        mockContract = await ethers.getContract("MockV3Aggregator", deployer);
        token = await ethers.getContract("TestToken", deployer);
      });
      describe("withdraw", () => {
        it("Should withdraw from saving account", async () => {
          const balanceBefore = await ethers.provider.getBalance(
            savingsContract.address
          );
          await deployer.sendTransaction({
            to: savingsContract.address,
            value: ethers.utils.parseEther("0.06"),
          });

          await savingsContract.setTokenAddress(
            token.address,
            mockContract.address
          );

          await network.provider.send("evm_increaseTime", [
            parseInt((await savingsContract.getTimePeriod()).toString()) + 5,
          ]);
          await network.provider.send("evm_mine", []);

          await savingsContract.sendToAccount(
            mockContract.address,
            ethers.constants.AddressZero,
            ethers.utils.parseEther("0.04"),
            false
          );
          const balanceAfrer = await ethers.provider.getBalance(
            savingsContract.address
          );

          assert(balanceBefore.toString() < balanceAfrer.toString());
        });
        it("Should fund", async () => {
          const balanceBefore = await ethers.provider.getBalance(
            savingsContract.address
          );
          await deployer.sendTransaction({
            to: savingsContract.address,
            value: amount,
          });
          const balanceAfrer = await ethers.provider.getBalance(
            savingsContract.address
          );
          assert(balanceBefore.toString() < balanceAfrer.toString());
        });
      });

      describe("target savings", () => {
        it("Should not withdraw if target not met", async () => {
          expect(async () => {
            await savingsContract.sendToAccount(
              mockContract.address,
              ethers.constants.AddressZero,
              ethers.utils.parseEther("0.5"),
              false
            );
          }).to.be.revertedWith("SAVING__TARGETNOTMET");
        });
        it("should not allow reset if time not passed", async () => {
          expect(async () => {
            await savingsContract.sendToAccount(
              mockContract.address,
              ethers.constants.AddressZero,
              "500000000000000000",
              false
            );
          }).to.be.revertedWith("SAVING__TARGETNOTMET");
        });
      });

      describe("get information", () => {
        it("should get details from contract", async () => {
          const time = await savingsContract.getTimePeriod();
          assert.equal(time.toString(), "86400");
        });
        it("amount set from deploy", async () => {
          const amount = await savingsContract.getAmountSet();
          assert.equal(
            amount.toString(),
            ethers.utils.parseEther("100").toString()
          );
        });
      });
    })
  : describe.skip;

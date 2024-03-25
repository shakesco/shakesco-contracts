const { network, deployments, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../../helper-hardhat-config");
const { assert, expect } = require("chai");
const fs = require("fs");

mockOnThisNetworks.includes(network.name)
  ? describe("BusinessSavings", () => {
      let deployer, user, accounts, savingsContract, mockContract, token;
      let amount = ethers.utils.parseEther("1");
      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        user = accounts[1];
        await deployments.fixture(["all"]);
        savingsContract = await ethers.getContract(
          "ShakescoBusinessSavings",
          deployer
        );
        mockContract = await ethers.getContract("MockV3Aggregator", deployer);
        token = await ethers.getContract("TestToken", deployer);
      });
      describe("busswithdraw", () => {
        it("Should withdraw from saving account", async () => {
          const balanceBefore = await ethers.provider.getBalance(
            savingsContract.address
          );
          await deployer.sendTransaction({
            to: savingsContract.address,
            value: ethers.utils.parseEther("2"),
          });
          await network.provider.send("evm_increaseTime", [
            parseInt((await savingsContract.getTimePeriod()).toString()) + 5,
          ]);
          await network.provider.send("evm_mine", []);
          await savingsContract.sendToBusiness(
            ethers.utils.parseEther("0.5"),
            mockContract.address
          );
          const balanceAfrer = await ethers.provider.getBalance(
            savingsContract.address
          );

          assert(balanceBefore.toString() < balanceAfrer.toString());

          //reset savings
          await savingsContract.resetTime(
            "259200",
            ethers.utils.parseEther("2")
          );
          const period = await savingsContract.getTimePeriod();
          const amounttoreach = await savingsContract.getAmountSet();
          assert.equal(period.toString(), "259200");
          assert.equal(
            amounttoreach.toString(),
            ethers.utils.parseEther("2").toString()
          );
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

      describe("Business target savings", () => {
        it("Should not withdraw if target not met", async () => {
          expect(async () => {
            await savingsContract.sendToBusiness(
              "500000000000000000",
              token.address,
              mockContract.address,
              mockContract.address,
              token.address
            );
          }).to.be.revertedWith("BUSINESSSAVING__TARGETNOTMET");
        });
        it("should not allow reset if time not passed", async () => {
          expect(async () => {
            await savingsContract.sendToBusiness(
              "500000000000000000",
              token.address,
              mockContract.address,
              mockContract.address,
              token.address
            );
          }).to.be.revertedWith("BUSINESSSAVING__TARGETNOTMET");
        });
      });

      describe("Business get information", () => {
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

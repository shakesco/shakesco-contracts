const { network, deployments, ethers } = require("hardhat");
const {
  mockOnThisNetworks,
  networkConfig,
} = require("../../helper-hardhat-config");
const { assert, expect } = require("chai");
const fs = require("fs");

mockOnThisNetworks.includes(network.name)
  ? describe("ShakesPay", () => {
      let deployer,
        user,
        accounts,
        savingsContract,
        businessSavingsContract,
        shakespay,
        businessToken,
        accountcontract,
        SHAKESPAYABI,
        vrfCoordinatorV2Mock;
      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        user = accounts[1];
        await deployments.fixture(["all"]);
        shakespay = await ethers.getContract("FromShakespay", deployer);
        savingsContract = await ethers.getContract("ShakescoSavings", deployer);
        businessSavingsContract = await ethers.getContract(
          "ShakescoBusinessSavings",
          deployer
        );
        businessToken = await ethers.getContract("TestToken", deployer);
        accountcontract = await ethers.getContract("ShakescoAccount", deployer);
        vrfCoordinatorV2Mock = await ethers.getContract(
          "VRFCoordinatorV2Mock",
          deployer
        );
        SHAKESPAYABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Shakesco/FromShakesco.sol/FromShakespay.json"
          )
        );
      });

      describe("constructor", () => {
        const chainId = network.config.chainId;
        it("address are the same for deployed contract", async () => {
          const contract2 = await shakespay.getVrfAddress();
          assert.equal(contract2, vrfCoordinatorV2Mock.address);
        });

        it("initializes the interval correctly", async () => {
          assert.equal(
            (await shakespay.getInterval()).toString(),
            networkConfig[chainId]["interval"]
          );
        });
        it("initializes the gasLimit correctly", async () => {
          const callGassLimit = await shakespay.getCallGasLimit();
          assert.equal(
            callGassLimit,
            networkConfig[chainId]["callbackGasLimit"]
          );
        });
        it("initializes the subID correctly", async () => {
          const subId = await shakespay.getSubId();
          assert.equal(
            subId.toString(),
            parseInt(networkConfig[chainId]["subscriptionId"]) + 1
          );
        });
        it("initializes the gasLane correctly", async () => {
          const gasLane = await shakespay.getGasLane();
          assert.equal(gasLane.toString(), networkConfig[chainId]["gasLane"]);
        });
      });

      describe("checkUpkeep", () => {
        it("returns false if people have not saved", async () => {
          await network.provider.send("evm_increaseTime", [
            parseInt((await shakespay.getInterval()).toString()) + 1,
          ]);
          await network.provider.send("evm_mine", []);
          const { upkeepNeeded } = await shakespay.checkUpkeep([]);
          assert(!upkeepNeeded);
        });
        it("should fail if account is not calling", async () => {
          expect(async () => {
            await shakespay.fundSavingForSaving(savingsContract.address);
          }).to.be.revertedWith("FROMSHAKESPAY__NOTSHAKESCOUSER");
        });
        it("Should fail if account has no funds", async () => {
          const shakesinterface = new ethers.utils.Interface(SHAKESPAYABI.abi);
          const call = shakesinterface.encodeFunctionData(
            "fundSavingForSaving",
            [savingsContract.address]
          );
          //using our wallet as entrypoint
          await accountcontract.execute(
            shakespay.address,
            ethers.utils.parseEther("0"),
            call
          );
          // await shakespay.fundSavingForSaving(accountcontract.address);
          await network.provider.send("evm_increaseTime", [
            parseInt((await shakespay.getInterval()).toString()) + 1,
          ]);
          await network.provider.send("evm_mine", []);
          const { upkeepNeeded } = await shakespay.checkUpkeep("0x");
          assert.equal(upkeepNeeded, false);
        });
        it("should return false if enough time hasn't passed", async () => {
          const tx0 = await deployer.sendTransaction({
            to: accountcontract.address,
            value: ethers.utils.parseEther("10"),
          });
          await tx0.wait(1);

          const shakesinterface = new ethers.utils.Interface(SHAKESPAYABI.abi);
          const call = shakesinterface.encodeFunctionData(
            "fundSavingForSaving",
            [savingsContract.address]
          );
          //using our wallet as entrypoint
          await accountcontract.execute(
            shakespay.address,
            ethers.utils.parseEther("1"),
            call
          );

          const { upkeepNeeded } = await shakespay.checkUpkeep("0x");
          assert.equal(upkeepNeeded, false);
        });
        it("returns true for everything", async () => {
          const tx0 = await deployer.sendTransaction({
            to: accountcontract.address,
            value: ethers.utils.parseEther("10"),
          });
          await tx0.wait(1);

          const shakesinterface = new ethers.utils.Interface(SHAKESPAYABI.abi);
          const call = shakesinterface.encodeFunctionData(
            "fundSavingForSaving",
            [savingsContract.address]
          );
          //using our wallet as entrypoint
          await accountcontract.execute(
            shakespay.address,
            ethers.utils.parseEther("5"),
            call
          );

          await network.provider.send("evm_increaseTime", [
            parseInt((await shakespay.getInterval()).toString()) + 1,
          ]);
          await network.provider.send("evm_mine", []);
          const { upkeepNeeded } = await shakespay.checkUpkeep("0x");
          assert(upkeepNeeded);
        });
      });

      describe("PerformUpKeep", () => {
        it("Can only run if checkUpkeep is true", async () => {
          const tx0 = await deployer.sendTransaction({
            to: accountcontract.address,
            value: ethers.utils.parseEther("5"),
          });
          await tx0.wait(1);

          const shakesinterface = new ethers.utils.Interface(SHAKESPAYABI.abi);
          const call = shakesinterface.encodeFunctionData(
            "fundSavingForSaving",
            [savingsContract.address]
          );
          //using our wallet as entrypoint
          await accountcontract.execute(
            shakespay.address,
            ethers.utils.parseEther("1"),
            call
          );

          await network.provider.send("evm_increaseTime", [
            parseInt((await shakespay.getInterval()).toString()) + 5,
          ]);
          await network.provider.send("evm_mine", []);
          await shakespay.performUpkeep([]);
          const tx = await shakespay.performUpkeep("0x");
          assert(tx);
        });
        it("reverts when checkUpkeep is false", async () => {
          expect(async () => {
            await shakespay.performUpkeep("0x");
          }).to.be.revertedWith("FROMSHAKESPAY__UPKEEPNOTNEEDED");
        });
      });

      describe("FulfilRandomWords", () => {
        beforeEach(async () => {
          const tx0 = await deployer.sendTransaction({
            to: accountcontract.address,
            value: ethers.utils.parseEther("5"),
          });
          await tx0.wait(1);
          await network.provider.send("evm_increaseTime", [
            parseInt((await shakespay.getInterval()).toString()) + 5,
          ]);
          await network.provider.send("evm_mine", []);
        });

        it("should only be called after performUpkeep", async () => {
          expect(async () => {
            await vrfCoordinatorV2Mock.fulfillRandomWords(0, shakespay.address);
          }).to.be.revertedWith("nonexistent request");
          expect(async () => {
            await vrfCoordinatorV2Mock.fulfillRandomWords(1, shakespay.address);
          }).to.be.revertedWith("nonexistent request");
        });

        it("send eth,select winner,reset participants and time", async () => {
          const tx1 = await deployer.sendTransaction({
            to: savingsContract.address,
            value: ethers.utils.parseEther("5"),
          });
          await tx1.wait(1);

          const tx2 = await deployer.sendTransaction({
            to: businessSavingsContract.address,
            value: ethers.utils.parseEther("5"),
          });
          await tx2.wait(1);

          const tx3 = await deployer.sendTransaction({
            to: accountcontract.address,
            value: ethers.utils.parseEther("5"),
          });
          await tx3.wait(1);

          const shakesinterface = new ethers.utils.Interface(SHAKESPAYABI.abi);
          const call = shakesinterface.encodeFunctionData(
            "fundSavingForSaving",
            [savingsContract.address]
          );
          const call2 = shakesinterface.encodeFunctionData(
            "fundSavingForSaving",
            [businessSavingsContract.address]
          );
          const call3 = shakesinterface.encodeFunctionData(
            "fundSavingForSaving",
            [accountcontract.address]
          );
          //using our wallet as entrypoint
          await accountcontract.executeBatch(
            [shakespay.address, shakespay.address, shakespay.address],
            [
              ethers.utils.parseEther("1"),
              ethers.utils.parseEther("1"),
              ethers.utils.parseEther("1"),
            ],
            [call, call2, call3]
          );

          const firstTimeStamp = await shakespay.getLatestTimestamp();
          await new Promise(async (resolve, reject) => {
            shakespay.once("PayForSaving", async () => {
              console.log("Event Found!!!");
              try {
                const participants = await shakespay.getNoOfSavers();
                const lastTimeStamp = await shakespay.getLatestTimestamp();
                const winnerLastBalance = await ethers.provider.getBalance(
                  accountcontract.address
                );
                const proceeds = await shakespay.shakescoProceeds();
                assert.equal(
                  proceeds.toString(),
                  ethers.utils.parseEther("0.15").toString()
                );
                assert.equal(participants.toString(), "0");
                assert(lastTimeStamp > firstTimeStamp);
                assert(winnerLastBalance > winnerStartingBalance);
                resolve();
              } catch (e) {
                console.log(e);
                reject();
              }
            });
            const tx = await shakespay.performUpkeep("0x");
            const txReceipt = await tx.wait(1);
            const winnerStartingBalance = await ethers.provider.getBalance(
              accountcontract.address
            );
            await vrfCoordinatorV2Mock.fulfillRandomWords(
              txReceipt.events[1].args.winner,
              shakespay.address
            );
          });
        });
      });
    })
  : describe.skip;

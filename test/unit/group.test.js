const { network, deployments, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../../helper-hardhat-config");
const { assert, expect } = require("chai");
const fs = require("fs");
const { argumentBytes } = require("./sample_data");

mockOnThisNetworks.includes(network.name)
  ? describe("Group", () => {
      let groupContract,
        deployer,
        user,
        accounts,
        accountContract,
        privateContract;

      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        user = accounts[1];
        await deployments.fixture(["all"]);

        groupContract = await ethers.getContract("ShakescoGroup", deployer);

        accountContract = await ethers.getContract("ShakescoAccount", deployer);

        privateContract = await ethers.getContract("ShakescoPrivate", deployer);
      });

      describe("Add members to group", () => {
        it("should not be able to request if request if off", async () => {
          expect(async () => {
            await groupContract.requestUsers(accountContract.address);
          }).to.be.revertedWith("SHAKESCOGROUP__TXFAILED");
        });

        it("request members to join", async () => {
          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");
        });

        it("should allow member to join", async () => {
          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);

          const members = await groupContract.getRequested();
          assert.equal(members[0].toString(), accountContract.address);
        });
      });

      describe("Transacting as group", () => {
        beforeEach(async () => {
          const tx0 = await deployer.sendTransaction({
            to: accountContract.address,
            value: ethers.utils.parseEther("10"),
          });
          await tx0.wait(1);
        });
        it("should not spend if not requested", async () => {
          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const calltwo = interface.encodeFunctionData("send", [
            groupContract.address,
            ethers.utils.parseEther("0.05"),
            "0x",
          ]);

          expect(async () => {
            await accountContract.execute(groupContract.address, 0, calltwo);
          }).to.be.revertedWith("SHAKESCOGROUP__NOTREQUESTED");
        });

        it("should not spend if not sent any funds", async () => {
          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);

          const groupABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );
          const groupinterface = new ethers.utils.Interface(groupABI.abi);

          const callthree = groupinterface.encodeFunctionData("send", [
            groupContract.address,
            ethers.utils.parseEther("0.05"),
            "0x",
          ]);

          expect(async () => {
            await accountContract.execute(groupContract.address, 0, callthree);
          }).to.be.revertedWith("ACCOUNT_TRANSACTIONFAILED"); //SHAKESCOGROUP__NOTENOUGHFUNDS
        });

        it("should spend only amount they have sent", async () => {
          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);

          const groupABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );
          const groupinterface = new ethers.utils.Interface(groupABI.abi);

          const callthree = groupinterface.encodeFunctionData("addFunds", []);

          await accountContract.execute(
            groupContract.address,
            ethers.utils.parseEther("1"),
            callthree
          );

          const test1 = await groupContract.getGroup();
          assert.equal(
            test1.groupBalance.toString(),
            ethers.utils.parseEther("1").toString()
          );

          const callfour = groupinterface.encodeFunctionData("send", [
            accountContract.address,
            ethers.utils.parseEther("0.5"),
            "0x",
          ]);

          await accountContract.execute(
            groupContract.address,
            ethers.constants.Zero,
            callfour
          );

          const test = await groupContract.getGroup();
          assert.equal(
            test.groupBalance.toString(),
            ethers.utils.parseEther("0.5").toString()
          );
        });

        it("Owner should not spend funds that are not theirs", async () => {
          expect(async () => {
            await groupContract.send(
              accountContract.address,
              ethers.utils.parseEther("0.5"),
              "0x"
            );
          }).to.be.revertedWith("SHAKESCOGROUP__NOTENOUGHFUNDS");
        });

        it("should spend privately", async () => {
          await groupContract.addFunds({ value: ethers.utils.parseEther("1") });

          const privateABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Shakesco/Private.sol/ShakescoPrivate.json"
            )
          );
          const privateinterface = new ethers.utils.Interface(privateABI.abi);

          const func = privateinterface.encodeFunctionData("sendEth", [
            accountContract.address,
            argumentBytes[0],
            argumentBytes[1],
          ]);

          await groupContract.send(
            privateContract.address,
            ethers.utils.parseEther("0.5"),
            func
          );

          const bal = await ethers.provider.getBalance(accountContract.address);

          assert.equal(
            bal.toString(),
            ethers.utils.parseEther("10.495").toString()
          );
        });

        it("should pay privately", async () => {
          await groupContract.addFunds({
            value: ethers.utils.parseEther("1"),
          });

          const privateABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Shakesco/Private.sol/ShakescoPrivate.json"
            )
          );
          const privateinterface = new ethers.utils.Interface(privateABI.abi);

          const func = privateinterface.encodeFunctionData("sendToBusiness", [
            accountContract.address,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            argumentBytes[0],
            argumentBytes[1],
          ]);

          await groupContract.sendToBusiness(
            privateContract.address,
            ethers.utils.parseEther("0.5"),
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            func
          );

          const bal = await ethers.provider.getBalance(accountContract.address);

          assert.equal(
            bal.toString(),
            ethers.utils.parseEther("10.495").toString()
          );
        });
      });

      describe("Savings", () => {
        beforeEach(async () => {
          const tx0 = await deployer.sendTransaction({
            to: accountContract.address,
            value: ethers.utils.parseEther("10"),
          });
          await tx0.wait(1);
        });

        it("should add to saving", async () => {
          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);

          const groupABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );
          const groupinterface = new ethers.utils.Interface(groupABI.abi);

          const callthree = groupinterface.encodeFunctionData(
            "addToSaving",
            []
          );

          await accountContract.execute(
            groupContract.address,
            ethers.utils.parseEther("1"),
            callthree
          );

          const test = await groupContract.getGroup();
          assert.equal(
            test.groupSavingContribution.toString(),
            ethers.utils.parseEther("1").toString()
          );
        });

        it("should not withdraw if target saving not reached", async () => {
          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);

          const groupABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );
          const groupinterface = new ethers.utils.Interface(groupABI.abi);

          const callthree = groupinterface.encodeFunctionData(
            "addToSaving",
            []
          );

          await accountContract.execute(
            groupContract.address,
            ethers.utils.parseEther("1"),
            callthree
          );

          const test = await groupContract.getGroup();
          assert.equal(
            test.groupSavingContribution.toString(),
            ethers.utils.parseEther("1").toString()
          );

          const callfour = groupinterface.encodeFunctionData(
            "withdrawSavings",
            [ethers.utils.parseEther("0.1")]
          );

          expect(async () => {
            await accountContract.execute(groupContract.address, 0, callfour);
          }).to.be.revertedWith("ACCOUNT_TRANSACTIONFAILED"); //SHAKESCOGROUP__TARGETNOTMET
        });

        it("should withdraw from savings", async () => {
          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);

          const groupABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );
          const groupinterface = new ethers.utils.Interface(groupABI.abi);

          const callthree = groupinterface.encodeFunctionData(
            "addToSaving",
            []
          );

          await accountContract.execute(
            groupContract.address,
            ethers.utils.parseEther("0.02"),
            callthree
          );

          const test = await groupContract.getGroup();
          assert.equal(
            test.groupSavingContribution.toString(),
            ethers.utils.parseEther("0.02").toString()
          );

          const saveDetails = await groupContract.getSavingInfo();

          await network.provider.send("evm_increaseTime", [
            parseInt(saveDetails[1].toString()) + 5,
          ]);
          await network.provider.send("evm_mine", []);

          const callfour = groupinterface.encodeFunctionData(
            "withdrawSavings",
            [ethers.utils.parseEther("0.01")]
          );

          await accountContract.execute(groupContract.address, 0, callfour);

          const saveDetailsAfter = await groupContract.getSavingInfo();
          assert.equal(saveDetailsAfter[0].toString(), "true");
        });
      });

      describe("split pay", () => {
        beforeEach(async () => {
          const tx0 = await deployer.sendTransaction({
            to: accountContract.address,
            value: ethers.utils.parseEther("10"),
          });
          await tx0.wait(1);
        });

        it("should not split if not enough amount", async () => {
          await groupContract.addFunds({ value: ethers.utils.parseEther("1") });
          expect(async () => {
            await groupContract.splitPay(
              accountContract.address,
              ethers.utils.parseEther("2")
            );
          }).to.be.revertedWith("SHAKESCOGROUP__NOTENOUGHFUNDS");
        });

        it("should split pay", async () => {
          await groupContract.addFunds({ value: ethers.utils.parseEther("1") });

          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);
          const groupABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );

          const groupinterface = new ethers.utils.Interface(groupABI.abi);

          const callthree = groupinterface.encodeFunctionData("addFunds", []);

          await accountContract.execute(
            groupContract.address,
            ethers.utils.parseEther("1"),
            callthree
          );

          await groupContract.splitPay(
            accountContract.address,
            ethers.utils.parseEther("1")
          );

          const details = await groupContract.getGroup();
          assert.equal(
            details.groupBalance[0].toString(),
            details.ownerBalance.toString()
          );
        });
      });

      describe("exit group", () => {
        beforeEach(async () => {
          const tx0 = await deployer.sendTransaction({
            to: accountContract.address,
            value: ethers.utils.parseEther("10"),
          });
          await tx0.wait(1);
        });

        it("should not allow owner to leave the group", async () => {
          expect(async () => {
            await groupContract.exitGroup();
          }).to.be.revertedWith("SHAKESCOGROUP__CANNOTREMOVESELF");
        });

        it("should exit group and send funds", async () => {
          await groupContract.addFunds({ value: ethers.utils.parseEther("1") });

          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);
          const groupABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );

          const groupinterface = new ethers.utils.Interface(groupABI.abi);

          const callthree = groupinterface.encodeFunctionData("addFunds", []);

          await accountContract.execute(
            groupContract.address,
            ethers.utils.parseEther("1"),
            callthree
          );

          const callfour = interface.encodeFunctionData("exitGroup", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, callfour);

          const bal = await ethers.provider.getBalance(groupContract.address);
          assert.equal(bal.toString(), ethers.utils.parseEther("1").toString());
        });
      });

      //to test below change target to true
      describe("Target", () => {
        beforeEach(async () => {
          const tx0 = await deployer.sendTransaction({
            to: accountContract.address,
            value: ethers.utils.parseEther("10"),
          });
          await tx0.wait(1);
        });

        it("should still contribute even if time elapsed", async () => {
          await groupContract.setTargetContribution(
            ethers.utils.parseEther("20"),
            604800
          );

          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);

          await network.provider.send("evm_increaseTime", [604800 + 5]);
          await network.provider.send("evm_mine", []);
          const groupABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );

          const groupinterface = new ethers.utils.Interface(groupABI.abi);

          const callthree = groupinterface.encodeFunctionData("addFunds", []);

          await accountContract.execute(
            groupContract.address,
            ethers.utils.parseEther("1"),
            callthree
          );
        });

        it("should not contibute if amount and time elapsed", async () => {
          await groupContract.setTargetContribution(
            ethers.utils.parseEther("20"),
            604800
          );

          const ACCABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
            )
          );
          const interface = new ethers.utils.Interface(ACCABI.abi);

          const call = interface.encodeFunctionData("changeRequestStatus", [
            "true",
          ]);

          await accountContract.execute(accountContract.address, 0, call);

          await groupContract.requestUsers(accountContract.address);

          const fee = await groupContract.getIfRequested(
            accountContract.address
          );

          assert.equal(fee.toString(), "true");

          const calltwo = interface.encodeFunctionData("acceptGroupInvite", [
            groupContract.address,
          ]);

          await accountContract.execute(accountContract.address, 0, calltwo);

          await network.provider.send("evm_increaseTime", [604800 + 5]);
          await network.provider.send("evm_mine", []);
          const groupABI = JSON.parse(
            fs.readFileSync(
              "artifacts/contracts/Users/ShakescoGroup.sol/ShakescoGroup.json"
            )
          );

          const groupinterface = new ethers.utils.Interface(groupABI.abi);

          const callthree = groupinterface.encodeFunctionData("addFunds", []);

          await accountContract.execute(
            groupContract.address,
            ethers.utils.parseEther("0.02"),
            callthree
          );

          expect(async () => {
            await groupContract.addFunds({
              value: ethers.utils.parseEther("0.01"),
            });
          }).to.be.revertedWith("SHAKESCOGROUP__CANNOTCONTRIBUTEANYMORE");
        });
      });
    })
  : describe.skip;

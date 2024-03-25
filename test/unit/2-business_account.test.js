const { network, deployments, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../../helper-hardhat-config");
const fs = require("fs");
const { assert, expect } = require("chai");

mockOnThisNetworks.includes(network.name)
  ? describe("business and account", () => {
      let businessContract,
        deployer,
        user,
        accounts,
        contractABI,
        accContract,
        businessToken,
        BUSINESSABI,
        TOKENABI,
        ACCABI,
        NFTABI,
        token,
        TESTTOKENABI,
        businessNFT;
      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        user = accounts[1];
        await deployments.fixture(["all"]);

        accContract = await ethers.getContract("ShakescoAccount", deployer);

        businessToken = await ethers.getContract(
          "ShakescoBusinessToken",
          deployer
        );
        businessNFT = await ethers.getContract("ShakescoBusinessNFT", deployer);
        businessContract = await ethers.getContract(
          "ShakescoBusinessContract",
          deployer
        );

        contractABI = await ethers.getContract("MockV3Aggregator", deployer);

        token = await ethers.getContract("TestToken", deployer);

        TESTTOKENABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Shakesco/TestToken.sol/TestToken.json"
          )
        );

        ACCABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Users/Account.sol/ShakescoAccount.json"
          )
        );

        TOKENABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Business/BusinessToken.sol/ShakescoBusinessToken.json"
          )
        );

        NFTABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Business/BusinessNFT.sol/ShakescoBusinessNFT.json"
          )
        );

        BUSINESSABI = JSON.parse(
          fs.readFileSync(
            "artifacts/contracts/Business/BusinessContract.sol/ShakescoBusinessContract.json"
          )
        );
      });

      describe("split pay business", () => {
        it("should pull if not allowed", async () => {
          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const call = accountABI.encodeFunctionData("pullSplitPay", [
            businessContract.address,
            ethers.utils.parseEther("0.5"),
          ]);

          expect(async () => {
            await businessContract.execute(
              accContract.address,
              ethers.constants.Zero,
              call
            );
          }).to.be.revertedWith("BUSINESSCONTRACT__TRANSACTIONFAILED");
        });

        it("should add split pay", async () => {
          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const calldata = accountABI.encodeFunctionData("acceptSplitPay", [
            businessContract.address,
            ethers.utils.parseEther("1"),
          ]);

          await accContract.execute(
            accContract.address,
            ethers.constants.Zero,
            calldata
          );
          const balance = await accContract.getSplitPay(
            businessContract.address
          );
          assert.equal(balance.toString(), (1e18).toString());
        });

        it("remove split pay", async () => {
          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const calldata = accountABI.encodeFunctionData("acceptSplitPay", [
            businessContract.address,
            ethers.utils.parseEther("1"),
          ]);

          await accContract.execute(
            accContract.address,
            ethers.constants.Zero,
            calldata
          );

          const call = accountABI.encodeFunctionData("removeSplitPay", [
            businessContract.address,
          ]);

          await accContract.execute(
            accContract.address,
            ethers.constants.Zero,
            call
          );
          const balance = await accContract.getSplitPay(
            businessContract.address
          );
          assert.equal(balance.toString(), "0");
        });

        it("should add split pay", async () => {
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });

          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const calldata = accountABI.encodeFunctionData("acceptSplitPay", [
            businessContract.address,
            ethers.utils.parseEther("1"),
          ]);

          await accContract.execute(
            accContract.address,
            ethers.constants.Zero,
            calldata
          );

          const call = accountABI.encodeFunctionData("pullSplitPay", [
            businessContract.address,
            ethers.utils.parseEther("0.5"),
          ]);

          await businessContract.execute(
            accContract.address,
            ethers.constants.Zero,
            call
          );

          const balance = await accContract.getSplitPay(
            businessContract.address
          );
          assert.equal(balance.toString(), (5e17).toString());
        });

        it("should not overspend", async () => {
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });

          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const calldata = accountABI.encodeFunctionData("acceptSplitPay", [
            businessContract.address,
            ethers.utils.parseEther("1"),
          ]);

          await accContract.execute(
            accContract.address,
            ethers.constants.Zero,
            calldata
          );

          const call = accountABI.encodeFunctionData("pullSplitPay", [
            businessContract.address,
            ethers.utils.parseEther("1.1"),
          ]);

          expect(async () => {
            await businessContract.execute(
              accContract.address,
              ethers.constants.Zero,
              call
            );
          }).to.be.revertedWith("BUSINESSCONTRACT__TRANSACTIONFAILED");
        });
      });

      describe("SendBusiness", () => {
        it("Should send without any nft or token", async () => {
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });

          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const calldata = accountABI.encodeFunctionData("sendToBusiness", [
            businessContract.address,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            contractABI.address,
            ethers.utils.parseEther("1"),
          ]);

          await accContract.execute(
            accContract.address,
            ethers.constants.Zero,
            calldata
          );
          const balance = await ethers.provider.getBalance(
            businessContract.address
          );

          assert.equal(
            balance.toString(),
            ethers.utils.parseEther("1").toString()
          );
        });
        it("should send with token discount only", async () => {
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });

          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const tokenABI = new ethers.utils.Interface(TOKENABI.abi);
          const middlecall = tokenABI.encodeFunctionData("buyToken", []);

          await accContract.execute(
            businessToken.address,
            ethers.utils.parseEther("0.06"),
            middlecall
          );

          const calldata = accountABI.encodeFunctionData("sendToBusiness", [
            businessContract.address,
            businessToken.address,
            ethers.constants.AddressZero,
            contractABI.address,
            ethers.utils.parseEther("0.07"),
          ]);

          await accContract.execute(
            accContract.address,
            ethers.constants.Zero,
            calldata
          );

          const balance = await ethers.provider.getBalance(
            businessContract.address
          );
          const tokenbalance = await businessToken.balanceOf(
            accContract.address
          );
          assert.equal(balance.toString(), "0");
          assert.equal(
            tokenbalance.toString(),
            ethers.utils.parseEther("0.54")
          );
        });
        it("should send with nft discount", async () => {
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });

          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const nftabi = new ethers.utils.Interface(NFTABI.abi);
          const middlecall = nftabi.encodeFunctionData("buyNft", [0]);

          await accContract.execute(
            businessNFT.address,
            ethers.utils.parseEther("0.06"),
            middlecall
          );

          const calldata = accountABI.encodeFunctionData("sendToBusiness", [
            businessContract.address,
            ethers.constants.AddressZero,
            businessNFT.address,
            contractABI.address,
            ethers.utils.parseEther("0.07"),
          ]);
          await accContract.execute(
            accContract.address,
            ethers.constants.Zero,
            calldata
          );
          const balance = await ethers.provider.getBalance(
            businessContract.address
          );
          assert.equal(
            balance.toString(),
            ethers.utils.parseEther(`0.04${"2".repeat(16)}`).toString()
          );
        });
      });

      describe("Send to employee", () => {
        it("should not send if no employee", async () => {
          await deployer.sendTransaction({
            to: businessContract.address,
            value: ethers.utils.parseEther("10"),
          });

          const accountABI = new ethers.utils.Interface(BUSINESSABI.abi);

          const calldata = accountABI.encodeFunctionData("sendToEmployees", [
            accContract.address,
          ]);

          expect(async () => {
            await accContract.execute(
              businessContract.address,
              ethers.constants.Zero,
              calldata
            );
          }).to.be.revertedWith("ACCOUNT_TRANSACTIONFAILED"); //BUSINESSCONTRACT__CANNOTPAYEMPLOYEE
        });

        it("should not send to wrong employee", async () => {
          await deployer.sendTransaction({
            to: businessContract.address,
            value: ethers.utils.parseEther("10"),
          });
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });

          const nftabi = new ethers.utils.Interface(NFTABI.abi);
          const addcall = nftabi.encodeFunctionData("addTeam", [
            0,
            accContract.address,
          ]);

          await businessContract.execute(
            businessNFT.address,
            ethers.constants.Zero,
            addcall
          );

          const bussabi = new ethers.utils.Interface(BUSINESSABI.abi);
          const middlecall = bussabi.encodeFunctionData("setPayToEmployee", [
            5,
            accContract.address,
          ]);

          await businessContract.execute(
            businessContract.address,
            ethers.constants.Zero,
            middlecall
          );

          const accountABI = new ethers.utils.Interface(BUSINESSABI.abi);
          const calldata = accountABI.encodeFunctionData("sendToEmployees", [
            deployer.address,
          ]);

          expect(async () => {
            await accContract.execute(
              businessContract.address,
              ethers.constants.Zero,
              calldata
            );
          }).to.revertedWith("BUSINESSCONTRACT__NOEMPLOYEE"); //BUSINESSCONTRACT__NOEMPLOYEE
        });

        it("should send to employee", async () => {
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });

          const nftabi = new ethers.utils.Interface(NFTABI.abi);
          const addcall = nftabi.encodeFunctionData("addTeam", [
            0,
            accContract.address,
          ]);

          await businessContract.execute(
            businessNFT.address,
            ethers.constants.Zero,
            addcall
          );

          const bussabi = new ethers.utils.Interface(BUSINESSABI.abi);
          const middlecall = bussabi.encodeFunctionData("setPayToEmployee", [
            5,
            businessNFT.address,
          ]);

          await businessContract.execute(
            businessContract.address,
            ethers.constants.Zero,
            middlecall
          );

          const accountABI = new ethers.utils.Interface(BUSINESSABI.abi);
          const calldata = accountABI.encodeFunctionData("sendToEmployees", [
            accContract.address,
          ]);
          await accContract.execute(
            businessContract.address,
            ethers.utils.parseEther("0.07"),
            calldata
          );
          const balance = await ethers.provider.getBalance(
            businessContract.address
          );
          assert.equal(
            balance.toString(),
            ethers.utils.parseEther("0.0665").toString()
          );
        });
      });
    })
  : describe.skip;

const { network, deployments, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../../helper-hardhat-config");
const fs = require("fs");
const { assert, expect } = require("chai");

mockOnThisNetworks.includes(network.name)
  ? describe("business and account", () => {
      let businessContract,
        deployer,
        savingsContract,
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
        savingsContract = await ethers.getContract("ShakescoSavings", deployer);

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
        it("should not pull if not allowed", async () => {
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

      describe("new auto save", () => {
        beforeEach(async () => {
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });
        });

        it("should not auto save if auto save if off", async () => {
          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const calldata = accountABI.encodeFunctionData("receiveAndSave", [
            ethers.constants.AddressZero,
            0,
          ]);

          await accContract.execute(
            accContract.address,
            ethers.utils.parseEther("1"),
            calldata
          );

          const balance = await ethers.provider.getBalance(
            savingsContract.address
          );

          assert.equal(balance.toString(), "0");
        });

        it("should auto save", async () => {
          const accountABI = new ethers.utils.Interface(ACCABI.abi);
          const setcalldata = accountABI.encodeFunctionData(
            "setSavingsAddress",
            [savingsContract.address, 5]
          );

          await accContract.execute(accContract.address, 0, setcalldata);

          const calldata = accountABI.encodeFunctionData("receiveAndSave", [
            ethers.constants.AddressZero,
            0,
          ]);

          await accContract.execute(
            accContract.address,
            ethers.utils.parseEther("1"),
            calldata
          );

          const balance = await ethers.provider.getBalance(
            savingsContract.address
          );

          assert.equal(
            balance.toString(),
            ethers.utils.parseEther("0.05").toString()
          );
        });
      });

      describe("SendBusiness", () => {
        it("Should send without any nft or token", async () => {
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });

          const accountABI = new ethers.utils.Interface(BUSINESSABI.abi);
          const calldata = accountABI.encodeFunctionData("sendToBusiness", [
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            contractABI.address,
          ]);

          await accContract.execute(
            businessContract.address,
            ethers.utils.parseEther("1"),
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

          const accountABI = new ethers.utils.Interface(BUSINESSABI.abi);
          const tokenABI = new ethers.utils.Interface(TOKENABI.abi);
          const middlecall = tokenABI.encodeFunctionData("buyToken", [
            contractABI.address,
          ]);

          await accContract.execute(
            businessToken.address,
            ethers.utils.parseEther("0.06"),
            middlecall
          );

          const calldata = accountABI.encodeFunctionData("sendToBusiness", [
            businessToken.address,
            ethers.constants.AddressZero,
            contractABI.address,
          ]);

          const midddlecall = tokenABI.encodeFunctionData("approve", [
            businessContract.address,
            ethers.utils.parseEther("2"),
          ]);

          await accContract.executeBatch(
            [businessToken.address, businessContract.address],
            [0, ethers.utils.parseEther("0.07")],
            [midddlecall, calldata]
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

          const accountABI = new ethers.utils.Interface(BUSINESSABI.abi);
          const nftabi = new ethers.utils.Interface(NFTABI.abi);
          const middlecall = nftabi.encodeFunctionData("buyNft", [
            0,
            ethers.constants.AddressZero,
            contractABI.address,
            0,
          ]);

          await accContract.execute(
            businessNFT.address,
            ethers.utils.parseEther("0.06"),
            middlecall
          );

          const calldata = accountABI.encodeFunctionData("sendToBusiness", [
            ethers.constants.AddressZero,
            businessNFT.address,
            contractABI.address,
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
            ethers.utils.parseEther(`0.04${"2".repeat(16)}`).toString()
          );
        });

        it("should receive erc20", async () => {
          await deployer.sendTransaction({
            to: accContract.address,
            value: ethers.utils.parseEther("10"),
          });

          await token.transfer(
            accContract.address,
            ethers.utils.parseEther("10")
          );

          const accountABI = new ethers.utils.Interface(BUSINESSABI.abi);

          const tokenABI = new ethers.utils.Interface(TOKENABI.abi);
          const middlecall = tokenABI.encodeFunctionData("buyToken", [
            contractABI.address,
          ]);

          await accContract.execute(
            businessToken.address,
            ethers.utils.parseEther("0.06"),
            middlecall
          );

          const calldata = accountABI.encodeFunctionData(
            "sendERC20ToBusiness",
            [
              token.address,
              businessToken.address,
              ethers.constants.AddressZero,
              contractABI.address,
              ethers.utils.parseEther("0.07"),
            ]
          );

          const token2 = new ethers.utils.Interface(TESTTOKENABI.abi);

          const midddlecall = token2.encodeFunctionData("approve", [
            businessContract.address,
            ethers.utils.parseEther("0.07"),
          ]);

          const midmidcal = tokenABI.encodeFunctionData("approve", [
            businessContract.address,
            ethers.utils.parseEther("2"),
          ]);

          await accContract.executeBatch(
            [token.address, businessToken.address, businessContract.address],
            [],
            [midddlecall, midmidcal, calldata]
          );

          const balance = await token.balanceOf(businessContract.address);
          const tokenbalance = await businessToken.balanceOf(
            accContract.address
          );
          assert.equal(balance.toString(), "0");
          assert.equal(
            tokenbalance.toString(),
            ethers.utils.parseEther("0.54")
          );
        });
      });
    })
  : describe.skip;

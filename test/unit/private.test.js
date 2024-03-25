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
          assert.equal(fee.toString(), "1");
        });
      });

      describe("Send ETH", () => {
        const amount = ethers.utils.parseEther("0.1");
        it("Should send eth privately", async () => {
          const fee = await private.getFee();
          await private.sendEth(accountContract.address, ...argumentBytes, {
            value: amount,
          });
          const balance = await ethers.provider.getBalance(
            accountContract.address
          );
          const balance2 = await ethers.provider.getBalance(private.address);

          const feeremoved = amount.mul(fee).div(100);
          const received = amount - feeremoved;
          assert.equal(balance.toString(), received.toString());
          assert.equal(feeremoved.toString(), balance2.toString());
        });
      });

      describe("send to Business", () => {
        it("should send to business without token", async () => {
          const fee = await private.getFee();
          const amount = ethers.utils.parseEther("0.2");
          await private.sendToBusiness(
            accountContract.address,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ...argumentBytes,
            { value: amount }
          );

          const feeremoved = amount.mul(fee).div(100);
          const received = amount - feeremoved;

          const balance = await ethers.provider.getBalance(
            accountContract.address
          );
          const privatebal = await ethers.provider.getBalance(private.address);
          assert.equal(balance.toString(), received.toString());
          assert.equal(privatebal.toString(), privatebal.toString());
        });
        it("should send to business with token", async () => {
          const amount = ethers.utils.parseEther("0.2");
          await deployer.sendTransaction({
            to: accountContract.address,
            value: ethers.utils.parseEther("10"),
          });
          const nft = new ethers.utils.Interface(NFTABI.abi);
          const call = nft.encodeFunctionData("buyNft", [0]);
          const token1 = new ethers.utils.Interface(TOKENABI.abi);
          const call2 = token1.encodeFunctionData("buyToken", []);

          const priv = new ethers.utils.Interface(PRIVATEABI.abi);
          const call3 = priv.encodeFunctionData("sendToBusiness", [
            token.address,
            businessToken.address,
            businessNFT.address,
            mockAddess.address,
            ...argumentBytes,
          ]);

          //using our wallet as entrypoint
          await accountContract.executeBatch(
            [businessNFT.address, businessToken.address],
            [ethers.utils.parseEther("0.2"), ethers.utils.parseEther("1")],
            [call, call2]
          );

          const balance = await businessToken.balanceOf(
            accountContract.address
          );

          const midddlecall = token1.encodeFunctionData("approve", [
            private.address,
            balance,
          ]);

          await accountContract.executeBatch(
            [businessToken.address, private.address],
            [ethers.constants.Zero, amount],
            [midddlecall, call3]
          );
          const accountBalance = await ethers.provider.getBalance(
            private.address
          );

          const tbalance = await ethers.provider.getBalance(token.address);
          const fee = amount.mul(1).div(100).toString();
          const tbalancet = await businessToken.balanceOf(token.address);
          const proceeds = await private.getProceeds(accountContract.address);

          assert.equal(accountBalance.toString(), amount.toString());
          assert.equal(tbalance.toString(), "0");
          assert(tbalancet.toString() > 0);
          assert.equal(proceeds.toString(), amount.sub(fee).toString());

          //withdraw proceeds.
          const call4 = priv.encodeFunctionData("payerProceeds", [proceeds]);
          await accountContract.execute(
            private.address,
            ethers.constants.Zero,
            call4
          );
          const proceedsAfterWithdraw = await private.getProceeds(
            accountContract.address
          );
          assert.equal(proceedsAfterWithdraw.toString(), "0");
          //withdraw fee
          await private.withdrawEthFee(token.address, fee);
          const balanceAfterWithdraw = await ethers.provider.getBalance(
            private.address
          );
          assert(balanceAfterWithdraw.toString(), "0");
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

const { network, deployments, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../../helper-hardhat-config");
const { assert } = require("chai");

// Prediction market outcome shares are ERC-1155. A safe transfer to a
// contract that lacks the receiver hooks reverts, so these must pass.
const WALLETS = [
  ["account", "ShakescoAccount"],
  ["business", "ShakescoBusinessContract"],
];

mockOnThisNetworks.includes(network.name)
  ? describe("ERC-1155 receiver", () => {
      let contracts, shares, deployer;

      beforeEach(async () => {
        const accounts = await ethers.getSigners();
        deployer = accounts[0];
        await deployments.fixture(["all"]);
        contracts = {};
        for (const [label, name] of WALLETS) {
          contracts[label] = await ethers.getContract(name, deployer);
        }
        shares = await ethers.getContract("TestERC1155", deployer);
      });

      it("control: a contract without the hooks rejects the transfer", async () => {
        const nft = await ethers.getContract("TestNFT", deployer);
        let reverted = false;
        try {
          await (await shares.mint(nft.address, 1, 50)).wait();
        } catch (e) {
          reverted = true;
        }
        assert.isTrue(reverted);
      });

      for (const [label] of WALLETS) {
        it(`${label}: accepts a single ERC-1155 transfer`, async () => {
          const wallet = contracts[label];
          await (await shares.mint(wallet.address, 1, 50)).wait();
          const balance = await shares.balanceOf(wallet.address, 1);
          assert.equal(balance.toString(), "50");
        });

        it(`${label}: accepts a batch ERC-1155 transfer`, async () => {
          const wallet = contracts[label];
          await (
            await shares.mintBatch(wallet.address, [1, 2], [10, 20])
          ).wait();
          const one = await shares.balanceOf(wallet.address, 1);
          const two = await shares.balanceOf(wallet.address, 2);
          assert.equal(one.toString(), "10");
          assert.equal(two.toString(), "20");
        });

        // Polymarket checks an order as a raw EIP-712 digest, with no
        // personal_sign prefix. The owner's typed-data signature must validate.
        it(`${label}: validates an owner-signed EIP-712 digest`, async () => {
          const wallet = contracts[label];
          const domain = {
            name: "Test Exchange",
            version: "1",
            chainId: network.config.chainId,
            verifyingContract: shares.address,
          };
          const types = {
            Order: [
              { name: "maker", type: "address" },
              { name: "tokenId", type: "uint256" },
              { name: "makerAmount", type: "uint256" },
            ],
          };
          const order = {
            maker: wallet.address,
            tokenId: 1,
            makerAmount: 1000000,
          };
          const signature = await deployer._signTypedData(
            domain,
            types,
            order
          );
          const digest = ethers.utils._TypedDataEncoder.hash(
            domain,
            types,
            order
          );
          assert.equal(
            await wallet.isValidSignature(digest, signature),
            "0x1626ba7e"
          );
        });
      }
    })
  : describe.skip("ERC-1155 receiver", () => {});

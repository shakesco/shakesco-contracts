const { network, deployments, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../../helper-hardhat-config");
const { assert } = require("chai");

// ERC-1271 magic value (bytes4(keccak256("isValidSignature(bytes32,bytes)")))
// and the sentinel returned on failure.
const MAGIC = "0x1626ba7e";
const INVALID = "0xffffffff";

mockOnThisNetworks.includes(network.name)
  ? describe("ERC-1271 isValidSignature", () => {
      let accContract, businessContract, deployer, other;

      beforeEach(async () => {
        const accounts = await ethers.getSigners();
        // In the mock env SHAKESCO == deployer, and both accounts are
        // initialized with SHAKESCO as owner, so deployer is the signer.
        deployer = accounts[0];
        other = accounts[1];
        await deployments.fixture(["all"]);
        accContract = await ethers.getContract("ShakescoAccount", deployer);
        businessContract = await ethers.getContract(
          "ShakescoBusinessContract",
          deployer
        );
      });

      it("account: returns the magic value for an owner-signed message", async () => {
        const message = "prove I own this account";
        const signature = await deployer.signMessage(message);
        const hash = ethers.utils.hashMessage(message);
        assert.equal(await accContract.isValidSignature(hash, signature), MAGIC);
      });

      it("account: rejects a signature from a non-owner", async () => {
        const message = "prove I own this account";
        const signature = await other.signMessage(message);
        const hash = ethers.utils.hashMessage(message);
        assert.equal(
          await accContract.isValidSignature(hash, signature),
          INVALID
        );
      });

      it("account: rejects a valid signature over a different message", async () => {
        const signature = await deployer.signMessage("message A");
        const hash = ethers.utils.hashMessage("message B");
        assert.equal(
          await accContract.isValidSignature(hash, signature),
          INVALID
        );
      });

      it("account: returns invalid (does not revert) on a malformed signature", async () => {
        const hash = ethers.utils.hashMessage("anything");
        assert.equal(
          await accContract.isValidSignature(hash, "0x1234"),
          INVALID
        );
      });

      it("business: returns the magic value for an owner-signed message", async () => {
        const message = "prove I own this business";
        const signature = await deployer.signMessage(message);
        const hash = ethers.utils.hashMessage(message);
        assert.equal(
          await businessContract.isValidSignature(hash, signature),
          MAGIC
        );
      });

      it("business: rejects a signature from a non-owner", async () => {
        const message = "prove I own this business";
        const signature = await other.signMessage(message);
        const hash = ethers.utils.hashMessage(message);
        assert.equal(
          await businessContract.isValidSignature(hash, signature),
          INVALID
        );
      });
    })
  : describe.skip("ERC-1271 isValidSignature", () => {});

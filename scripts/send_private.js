const { ethers } = require("hardhat");
const fs = require("fs");
const {
  signMessage,
  generateKeyPair,
} = require("../../../shakesco/javascript/generate_keys");
const {
  KeyPair,
  StealthKeyRegistry,
  RandomNumber,
} = require("@shakesco/private");
require("dotenv").config({
  path: "C:/Users/User/Desktop/Solidity/shakespay/.env",
});
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);

async function sendprivate() {
  const private = await ethers.getContract("ShakescoPrivate");
  const addressITHINK = "0x54F8Ccbb80DBBEE286B4B65c37382A66CC10d91B";

  const { stealthKeyPair, pubKeyXCoordinate, encrypted } = await prepareSend(
    addressITHINK,
    provider
  );

  const send = await private.sendEth(
    stealthKeyPair.address,
    pubKeyXCoordinate,
    encrypted.ciphertext,
    { value: ethers.utils.parseEther("0.02") }
  );

  const receipt = await send.wait();
  console.log(receipt);
  console.log("SENT PRIVATELY");
}

async function testDecrypt() {
  const pkx =
    "0x382945d34ba2b931643adbb32279a68ea51ce5a000b6a1aa15d4f206b2e84e7d";
  const ciphertext =
    "0xaca4db4f839a8a0f05fe405b6baa13c26667422a27776536671153354cc2e697";
  const uncompressedPubKey = KeyPair.getUncompressedFromX(pkx);

  const wallet = new ethers.Wallet(process.env.PRIV_KEY, provider);
  const sign = await wallet.signMessage(await signMessage(provider));

  const { spendingKeyPair, viewingKeyPair } = await generateKeyPair(sign);

  const payload = { ephemeralPublicKey: uncompressedPubKey, ciphertext };
  const viewkey = new KeyPair(viewingKeyPair.privateKeyHex);
  const randomNumber = await viewkey.decrypt(payload);
  const registry = new StealthKeyRegistry(provider);
  const { spendingPublicKey } = await registry.getStealthKeys(
    "0xDF56E8f14BeCb8d6a7CC98020eEDB17eaCB0fae8"
  );

  // Get what our receiving address would be with this random number
  const spendingkey = new KeyPair(spendingPublicKey);
  const computedReceivingAddress =
    spendingkey.mulPublicKey(randomNumber).address;
  const address = "0xec1ae327c380e9B97219c88cE273b95ED34a0cC7";

  console.log(address);
  console.log(computedReceivingAddress);
  console.log(randomNumber);
}

async function sendAfter() {
  const privkey = KeyPair.computeStealthPrivateKey(
    "0x02fb6a1b7dfbe7d1b157fb8a41b23980f4a055e75c5d5d4b73a7a449d42ea54a",
    "0x0c782709020fc587e11c48dcdc5263f9c8573654ccc697e40952115aabfd3fea"
  );

  const wallet = new ethers.Wallet(privkey, provider);
  console.log(wallet.address);
  const tx = await wallet.sendTransaction({
    to: "0xf765843BbD0230d512C2e29dc9b00E5EcdDBdDBb",
    value: ethers.utils.parseEther("0.007"),
  });
  const receipt = await tx.wait();
  console.log(receipt);
  console.log("WITHDREWWW!!!");
}

sendprivate()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });

async function prepareSend(recipientId, provider) {
  // Lookup recipient's public key
  const registry = new StealthKeyRegistry(provider);

  const { spendingPublicKey, viewingPublicKey } = await registry.getStealthKeys(
    recipientId
  );
  if (!spendingPublicKey || !viewingPublicKey) {
    throw new Error(
      `Could not retrieve public keys for recipient ID ${recipientId}`
    );
  }

  const spendingKeyPair = new KeyPair(spendingPublicKey);
  const viewingKeyPair = new KeyPair(viewingPublicKey);

  // Generate random number
  const randomNumber = new RandomNumber();

  // Encrypt random number with recipient's public key
  const encrypted = await viewingKeyPair.encrypt(randomNumber);

  // Get x,y coordinates of ephemeral private key
  const { pubKeyXCoordinate } = KeyPair.compressPublicKey(
    encrypted.ephemeralPublicKey
  );

  // Compute stealth address
  const stealthKeyPair = spendingKeyPair.mulPublicKey(randomNumber);

  return { stealthKeyPair, pubKeyXCoordinate, encrypted };
}

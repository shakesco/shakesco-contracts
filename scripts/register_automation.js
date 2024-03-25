const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config({
  path: "C:/Users/User/Desktop/Solidity/shakespay/.env",
});
const provider = new ethers.providers.JsonRpcProvider(process.env.MATICRPC_URL);

async function registerUpkeep() {
  const auto = await ethers.getContract("ShakescoAutoPayment");
  const automate = await ethers.getContract("Automate");

  const send = await automate.createUpkeep([
    "ShakescoTest",
    "0x",
    auto.address,
    "300000",
    "0xD03EAc6b2d53B00baF997490801Bb5F211b6514A",
    0,
    "0x",
    "0x",
    "0x",
    "4000000000000000000",
  ]);

  const receipt = await send.wait();
  console.log(receipt);
  console.log("REGISTED UPKEEP");
}

async function withdraw() {
  const automate = await ethers.getContract("Automate");
  const send = await automate.withdraw();
  const receipt = await send.wait();
  console.log(receipt);
  console.log("WITHDREW");
}

async function setPull() {
  const auto = await ethers.getContract("ShakescoAutoPayment");
  const delegate = await ethers.getContract("ShakescoDelegateAccount");
  const setpull = await delegate.createPermissionFAF(
    auto.address,
    500,
    0,
    ethers.utils.parseEther("0.00001")
  );
  await setpull.wait();
  const accept = await delegate.acceptRequest(auto.address);
  await accept.wait();
  const set = await auto.addPayer(delegate.address);
  await set.wait();
  console.log("EVERYTHING IS SET");
  console.log("CHECK DEL: \n", delegate.address);
  console.log("CHECK AUTO: \n", auto.address);
}

setPull()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });

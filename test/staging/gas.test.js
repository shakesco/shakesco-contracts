const { randomInt } = require("crypto");
const ethers = require("ethers");
const { hexDataSlice } = require("ethers/lib/utils");
require("dotenv").config({
  path: "C:/Users/User/Desktop/Solidity/shakespay/.env",
});
const fs = require("fs");

async function test() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const maxFeePerGas = `0x${(
    await provider.getFeeData()
  ).maxFeePerGas.toString()}`;
  const maxPriorityFeePerGas = `0x${(
    await provider.getFeeData()
  ).maxPriorityFeePerGas.toString()}`;
  console.log("Priority", maxPriorityFeePerGas);
  console.log("Fee gas", maxFeePerGas);

  //calldata
  const contractABI = JSON.parse(
    fs.readFileSync(
      "../../artifacts/contracts/Users/Account.sol/ShakescoAccount.json",
      "utf8"
    )
  );
  const accountABI = new ethers.utils.Interface(contractABI.abi);
  const calldata = accountABI.encodeFunctionData("execute", [
    "0x4Ab6a994F5A59346c19D49f3143B905a405cbb7a",
    ethers.utils.parseEther("0.6"),
    "0x",
  ]);

  //callgaslimit
  const gasEstimated = await provider.estimateGas({
    from: "0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789",
    to: "0x03D55B3f240D2cD21CBF25dFad374d0b3afaFC26",
    data: calldata,
  });

  const factoryABI = JSON.parse(
    fs.readFileSync(
      "../../artifacts/contracts/Factory/AccountFactory.sol/ShakescoAccountFactory.json",
      "utf8"
    )
  );

  const factory = new ethers.utils.Interface(factoryABI.abi);
  const initCode = ethers.utils.hexConcat([
    "0xF8b96F0DbAC3890d5c019b6aC4a03268Ca7B1205",
    factory.encodeFunctionData("deployWallet", [
      "0x4Ab6a994F5A59346c19D49f3143B905a405cbb7a",
      "0",
    ]),
  ]);

  const initEstimate = await provider.estimateGas({
    from: "0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789",
    to: hexDataSlice(initCode, 0, 20),
    data: hexDataSlice(initCode, 20),
    gasLimit: 10e6,
  });

  console.log("callgaslimit", gasEstimated.add(55000));
  console.log(
    "verification_with_initcode",
    ethers.BigNumber.from("150000").add(initEstimate)
  );
}

// test();

async function testing123() {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.MATICRPC_URL
  );

  const wallet = new ethers.Wallet(process.env.PRIV_KEY2, provider);

  const sendtx = await wallet.sendTransaction({
    to: "0x3c969250F42315DA38cE849cFbBc581e60FC96Ae",
    value: ethers.utils.parseEther("0.8"),
  });
  const result = await sendtx.wait();
  console.log(result);
}

testing123();

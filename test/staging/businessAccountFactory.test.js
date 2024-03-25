const { network, deployments, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../../helper-hardhat-config");
const fs = require("fs");
const { assert, expect } = require("chai");
const axios = require("axios");

mockOnThisNetworks.includes(network.name)
  ? describe("BusinessAccountFactory", () => {
      let businessFactory, contractABI;
      beforeEach(async () => {
        contractABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Factory/BusinessAccountFactory.sol/BusinessFactory.json",
            "utf8"
          )
        );
        const provider = new ethers.providers.JsonRpcProvider(
          process.env.MATICRPC_URL
        );

        const wallet = new ethers.Wallet(process.env.PRIV_KEY, provider);
        const signer = await wallet.provider.getSigner(wallet.address);
        businessFactory = new ethers.Contract(
          "0x44f62B6e292C6F9Da49b81cA4d62c8553f8fe2dE",
          contractABI.abi,
          signer
        );
      });

      describe("Compute Address", () => {
        it("should compute business addresses", async () => {
          const address = await businessFactory.computeAddress(
            "0xf765843BbD0230d512C2e29dc9b00E5EcdDBdDBb",
            ethers.utils.parseEther("0.01"),
            0
          );
          const code = await ethers.provider.getCode(address);
          assert(code.toString() == "0x");
          console.log(address.toString());
        });
      });

      describe("Deploy Wallet", () => {
        it("Should deploy business wallet", async () => {
          const sender = "0x2188E137Ceb00c8A492876343dcf919A81091f67";
          const nonce = "0x0";
          const callGasLimit = "0x60000";
          const verificationGasLimit = "0x150000";
          const preVerificationGas = "0x48000";
          const maxFeePerGas = `0x${(
            await ethers.provider.getFeeData()
          ).maxFeePerGas.toString()}`;
          const maxPriorityFeePerGas = `0x${(
            await ethers.provider.getFeeData()
          ).maxPriorityFeePerGas.toString()}`;

          const factory = new ethers.utils.Interface(contractABI.abi);
          const initCode = ethers.utils.hexConcat([
            businessFactory.address,
            factory.encodeFunctionData("deployWallet", [
              "0xf765843BbD0230d512C2e29dc9b00E5EcdDBdDBb",
              ethers.utils.parseEther("0.01"),
              "0",
            ]),
          ]);
          // console.log("initCode :", initCode);

          const getUserOpHash = () => {
            const packed = ethers.utils.defaultAbiCoder.encode(
              [
                "address",
                "uint256",
                "bytes32",
                "bytes32",
                "uint256",
                "uint256",
                "uint256",
                "uint256",
                "uint256",
                "bytes32",
              ],
              [
                sender,
                nonce,
                ethers.utils.keccak256(initCode),
                ethers.utils.keccak256("0x"),
                callGasLimit,
                verificationGasLimit,
                preVerificationGas,
                maxFeePerGas,
                maxPriorityFeePerGas,
                ethers.utils.keccak256("0x"),
              ]
            );
            const enc = ethers.utils.defaultAbiCoder.encode(
              ["bytes32", "address", "uint256"],
              [
                ethers.utils.keccak256(packed),
                "0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789",
                "80001",
              ]
            );

            return ethers.utils.keccak256(enc);
          };
          const arraifiedHash = ethers.utils.arrayify(getUserOpHash());
          // console.log("arraified Hash :", arraifiedHash);

          //sign-> TSS
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          const signer = new ethers.Wallet(process.env.PRIV_KEY, provider);
          const signature = await signer.signMessage(arraifiedHash);
          // console.log("signature :", signature);

          const options = {
            method: "POST",
            url: process.env.STACKUPAPIKEY,
            headers: {
              accept: "application/json",
              "content-type": "application/json",
            },
            data: JSON.stringify({
              id: 1,
              jsonrpc: "2.0",
              method: "eth_sendUserOperation",
              params: [
                {
                  sender: sender,
                  nonce: nonce,
                  initCode: initCode,
                  callData: "0x",
                  callGasLimit: callGasLimit,
                  verificationGasLimit: verificationGasLimit,
                  preVerificationGas: preVerificationGas,
                  maxFeePerGas: maxFeePerGas,
                  maxPriorityFeePerGas: maxPriorityFeePerGas,
                  signature: signature,
                  paymasterAndData: "0x",
                },
                "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
              ],
            }),
          };

          // await axios
          //   .request(options)
          //   .then(function (response) {
          //     console.log(response.data);
          //   })
          //   .catch(function (error) {
          //     console.error(error);
          //   });

          //success
          // {
          //   id: 1,
          //   jsonrpc: '2.0',
          //   result: '0x45a43533c370bf7cc836c9f66d5dbb57b8ca50713bd62682aa98237c7e6ba369'
          // }
        });
      });
    })
  : describe.skip;

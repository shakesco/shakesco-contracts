const { network, deployments, ethers } = require("hardhat");
const {
  mockOnThisNetworks,
  ENTRYPOINT,
} = require("../../helper-hardhat-config");
const fs = require("fs");
const { assert, expect } = require("chai");
const axios = require("axios");
const { BigNumber } = require("ethers");
const { hexDataSlice } = require("ethers/lib/utils");

mockOnThisNetworks.includes(network.name)
  ? describe("AccountFactory", () => {
      let accFactoryContract,
        contractABI,
        ACCOUNT,
        factoryABI,
        NFT,
        TOKEN,
        TOKENABI,
        entrypointABI,
        NFTABI;
      beforeEach(async () => {
        await deployments.fixture(["all"]);

        contractABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Users/Account.sol/ShakescoAccount.json",
            "utf8"
          )
        );

        factoryABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Factory/AccountFactory.sol/ShakescoAccountFactory.json",
            "utf8"
          )
        );

        NFTABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Factory/BusinessNFTFactory.sol/ShakescoBusinessNFTFactory.json",
            "utf8"
          )
        );

        TOKENABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Factory/BusinessTokenFactory.sol/ShakescoBusinessTokenFactory.json",
            "utf8"
          )
        );

        entrypointABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/@account-abstraction/contracts/core/EntryPoint.sol/EntryPoint.json",
            "utf8"
          )
        );

        const provider = new ethers.providers.JsonRpcProvider(
          process.env.MATICRPC_URL
        );

        accFactoryContract = new ethers.Contract(
          "0xF273a9D3C6C94955F4b32a769292a997c3abDf61",
          factoryABI.abi,
          provider
        );

        ACCOUNT = new ethers.Contract(
          "0xB8C0450dc4b1D8ff172307cCe101B62F9878F3DE",
          contractABI.abi,
          provider
        );

        NFT = new ethers.Contract(
          "0x485f6443253b075595C5783A69dD243D7080898A",
          NFTABI.abi,
          provider
        );

        TOKEN = new ethers.Contract(
          "0x1C7e8c2de7d5935033Be177627518EA7eb9408Bb",
          TOKENABI.abi,
          provider
        );
      });

      describe("Compute Address", () => {
        it("should compute users addresses", async () => {
          const address = await accFactoryContract.computeAddress(
            "0xDF56E8f14BeCb8d6a7CC98020eEDB17eaCB0fae8",
            0
          );
          console.log(address.toString());
        });
      });

      describe("compute token and nft address", () => {
        it("should compute nft address", async () => {
          const compute = await NFT.computeAddress(
            "Shakespay",
            "SKK",
            [
              "ipfs://QmfU9zAXU8xjDgHRCpRwR4b1EqAW8E2N8DwV53vUD2y3Pc",
              "ipfs://QmNU8T55gSsZ4YQae7ts97XWzhAfbkzSV9uboMzYmM1cmi",
              "ipfs://QmXdPFqyAMwMihLcLq8EUxJWCtXHWXBbULjhuHxfw1tRsR",
            ],
            1,
            5,
            1000000,
            0,
            "0xB8C0450dc4b1D8ff172307cCe101B62F9878F3DE",
            false,
            false
          );
          console.log(compute);
        });

        it("should compute sbt address", async () => {
          const compute = await NFT.computeAddress(
            "GOOGLE",
            "GGG",
            [
              "ipfs://QmfU9zAXU8xjDgHRCpRwR4b1EqAW8E2N8DwV53vUD2y3Pc",
              "ipfs://QmNU8T55gSsZ4YQae7ts97XWzhAfbkzSV9uboMzYmM1cmi",
              "ipfs://QmXdPFqyAMwMihLcLq8EUxJWCtXHWXBbULjhuHxfw1tRsR",
            ],
            "10",
            "3",
            "0",
            191363464452394,
            "0xB8C0450dc4b1D8ff172307cCe101B62F9878F3DE",
            false,
            true
          );
          console.log(compute);
        });

        it("should compute token address", async () => {
          const compute = await TOKEN.computeAddress(
            "Shakesco",
            "SKK",
            "2100000",
            "1", //in usd
            "5", //e.g: 5
            "5", //e.g: 5
            "10",
            0,
            "0xB8C0450dc4b1D8ff172307cCe101B62F9878F3DE"
          );
          console.log(compute);
        });

        it("should compute token address", async () => {
          const compute = await TOKEN.computeAddress(
            "Shakespay",
            "SKK",
            "2100000",
            "1", //in usd
            "5", //e.g: 5
            "5", //e.g: 5
            "10",
            0,
            "0xB8C0450dc4b1D8ff172307cCe101B62F9878F3DE"
          );
          console.log(compute);
        });
      });

      describe("Deploy Wallet", () => {
        it("Should deploy users wallet", async () => {
          const sender = "0xA51b54a5550f3655CB1038b90cdC283eF9D6b47C";
          const nonce = "0x1";

          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          const block = await provider.getBlock("latest");

          const maxFeePerGas = block.baseFeePerGas
            .add((await provider.getFeeData()).maxFeePerGas)
            .toString();
          const maxPriorityFeePerGas = (
            await provider.getFeeData()
          ).maxPriorityFeePerGas.toString();

          const accountABI = new ethers.utils.Interface(contractABI.abi);

          const calldata = accountABI.encodeFunctionData("execute", [
            "0xf4c602B796AC24a3FFe49f28d67987A98801627F",
            ethers.utils.parseEther("0.3"),
            "0x",
          ]); //

          const callGasEstimate = await provider.estimateGas({
            from: "0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789",
            to: sender,
            data: calldata ? calldata : "0x",
          });

          const callGasLimit =
            "0x" + BigNumber.from(callGasEstimate).add("0xc350").toString();

          const preVerificationGas = callGasEstimate.add("21000")._hex;

          // const factory = new ethers.utils.Interface(factoryABI.abi);
          // const initCode = ethers.utils.hexConcat([
          //   accFactoryContract.address,
          //   factory.encodeFunctionData("deployWallet", [
          //     "0xDF56E8f14BeCb8d6a7CC98020eEDB17eaCB0fae8",
          //     "0",
          //   ]),
          // ]);

          // const initEstimate = await provider.estimateGas({
          //   from: ENTRYPOINT,
          //   to: hexDataSlice(initCode, 0, 20),
          //   data: hexDataSlice(initCode, 20),
          //   gasLimit: 10e6,
          // });
          // initEstimate.add("100000")._hex;

          const verificationGasLimit = "0x0186a0";

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
                ethers.utils.keccak256("0x"),
                ethers.utils.keccak256(calldata),
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

          const signer = new ethers.Wallet(process.env.PRIV_KEY, provider);
          const signature = await signer.signMessage(arraifiedHash);
          // console.log("signature :", signature);

          console.log("signature :", signature);
          return;

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
                  initCode: "0x",
                  callData: calldata,
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

          await axios
            .request(options)
            .then(function (response) {
              console.log(response.data);
            })
            .catch(function (error) {
              console.error(error);
            });

          //output(Mumbai)
        });
      });
    })
  : describe.skip;

const { network, ethers } = require("hardhat");
const { mockOnThisNetworks } = require("../../helper-hardhat-config");
const { expect } = require("chai");
const fs = require("fs");
const axios = require("axios");

//This test covers buiness and account send and send to many eth
//send and send to many token(NFT and token)

!mockOnThisNetworks.includes(network.name)
  ? describe("Account", () => {
      let accContract,
        contractABI,
        ERC20PARTIALABI,
        ERC721PARTIALABI,
        accountABI,
        ERC20ABI,
        ERC721ABI;
      beforeEach(async () => {
        contractABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Users/Account.sol/Account.json",
            "utf8"
          )
        );
        const provider = new ethers.providers.JsonRpcProvider(
          process.env.MATICRPC_URL
        );

        const wallet = new ethers.Wallet(process.env.PRIV_KEY2, provider);
        const signer = await wallet.provider.getSigner(wallet.address);
        accContract = new ethers.Contract(
          "0x0b781e36657575d49782128cCA3bD23293e6fc99",
          contractABI.abi,
          signer
        );

        ERC20PARTIALABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json",
            "utf8"
          )
        );

        ERC721PARTIALABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/@openzeppelin/contracts/token/ERC721/IERC721.sol/IERC721.json",
            "utf8"
          )
        );
      });

      describe("Execute", () => {
        it("Should ETH from contract account", async () => {
          const sender = "0x0b781e36657575d49782128cCA3bD23293e6fc99";
          const nonce = `0x${(await accContract.getNonce()).toString()}`;
          const callGasLimit = "0x90000";
          const verificationGasLimit = "0x150000";
          const preVerificationGas = "0x48000";
          const maxFeePerGas = `0x${(
            await ethers.provider.getFeeData()
          ).maxFeePerGas.toString()}`;
          const maxPriorityFeePerGas = `0x${(
            await ethers.provider.getFeeData()
          ).maxPriorityFeePerGas.toString()}`;
          const accountABI = new ethers.utils.Interface(contractABI.abi);
          const calldata = accountABI.encodeFunctionData("execute", [
            "0xeA32aDb911511d67e4F800c4e5FfD69755d738Fe",
            "1000000000000000",
            "0x",
          ]);
          // console.log(calldata);

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
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          const signer = new ethers.Wallet(process.env.PRIV_KEY, provider);
          const signature = await signer.signMessage(arraifiedHash);
          console.log(arraifiedHash);

          //send
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

          // await axios
          //   .request(options)
          //   .then((response) => {
          //     console.log(response.data);
          //   })
          //   .catch(function (error) {
          //     console.error(error);
          //   });
          //success
          // {
          //   id: 1,
          //   jsonrpc: '2.0',
          //   result: '0x4486fbdf7d1174a07c1b78d150cbd44f4d141d37dbe4e91c623385484e178d2a'
          // }
        });

        it("should send ETH to many from contract", async () => {
          const calldata = accountABI.encodeFunctionData("executeBatch", [
            [
              "0xeA32aDb911511d67e4F800c4e5FfD69755d738Fe",
              "0xeA32aDb911511d67e4F800c4e5FfD69755d738Fe",
            ],
            ["1000000000000000", "1000000000000000"],
            ["0x", "0x"],
          ]);
          // console.log(calldata);

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
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          const signer = new ethers.Wallet(process.env.PRIV_KEY, provider);
          const signature = await signer.signMessage(arraifiedHash);

          //send
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

          // await axios
          //   .request(options)
          //   .then((response) => {
          //     console.log(response.data);
          //   })
          //   .catch(function (error) {
          //     console.error(error);
          //   });
          //success
          // {
          //   id: 1,
          //   jsonrpc: '2.0',
          //   result: '0x2be421fcabf80a5d1cddd3cff536203eac1442c1ae125b48edaf0e7c5dbb468c'
          // }
        });
      });

      describe("Withdraw Tokens", async () => {
        it("should withdraw erc20 from contract", async () => {
          const calldata = accountABI.encodeFunctionData("execute", [
            "0x326C977E6efc84E512bB9C30f76E30c160eD06FB", //chainlink token in mumbai
            ethers.constants.Zero,
            ERC20ABI.encodeFunctionData("transfer", [
              "0xeA32aDb911511d67e4F800c4e5FfD69755d738Fe",
              "1000000000000000000",
            ]),
          ]);
          // console.log(calldata);

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
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          const signer = new ethers.Wallet(process.env.PRIV_KEY, provider);
          const signature = await signer.signMessage(arraifiedHash);

          //send
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

          // await axios
          //   .request(options)
          //   .then((response) => {
          //     console.log(response.data);
          //   })
          //   .catch(function (error) {
          //     console.error(error);
          //   });
          //success
          // {
          //   id: 1,
          //   jsonrpc: '2.0',
          //   result: '0xfb7ede86e4fe511769f2fe803bdbc9b75df2919140f03a568618624ccc74f6bb'
          // }
        });

        it("should send token to many from contract", async () => {
          const calldata = accountABI.encodeFunctionData("executeBatch", [
            [
              "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
              "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
            ], //chainlink token in mumbai
            [ethers.constants.Zero, ethers.constants.Zero],
            [
              ERC20ABI.encodeFunctionData("transfer", [
                "0xeA32aDb911511d67e4F800c4e5FfD69755d738Fe",
                "1000000000000000000",
              ]),
              ERC20ABI.encodeFunctionData("transfer", [
                "0xeA32aDb911511d67e4F800c4e5FfD69755d738Fe",
                "1000000000000000000",
              ]),
            ],
          ]);
          // console.log(calldata);

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
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          const signer = new ethers.Wallet(process.env.PRIV_KEY, provider);
          const signature = await signer.signMessage(arraifiedHash);

          //send
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

          // await axios
          //   .request(options)
          //   .then((response) => {
          //     console.log(response.data);
          //   })
          //   .catch(function (error) {
          //     console.error(error);
          //   });
          //success
          // {
          //   id: 1,
          //   jsonrpc: '2.0',
          //   result: '0x56e3c3df6d63e6cc1d71c1e34ade00dce24e7c34ce40765400f40af3f691887f'
          // }
        });
      });

      describe("NFT", async () => {
        let sender,
          nonce,
          callGasLimit,
          verificationGasLimit,
          preVerificationGas,
          maxFeePerGas,
          maxPriorityFeePerGas,
          accountABI;
        beforeEach(async () => {
          sender = "0x0b781e36657575d49782128cCA3bD23293e6fc99";
          nonce = `0x${await accContract.getNonce()}`;
          callGasLimit = "0x90000";
          verificationGasLimit = "0x150000";
          preVerificationGas = "0x48000";
          maxFeePerGas = `0x${(
            await ethers.provider.getFeeData()
          ).maxFeePerGas.toString()}`;
          maxPriorityFeePerGas = `0x${(
            await ethers.provider.getFeeData()
          ).maxPriorityFeePerGas.toString()}`;
          accountABI = new ethers.utils.Interface(contractABI.abi);
        });
        it("Should transfer NFT from contract", async () => {
          const calldata = accountABI.encodeFunctionData("execute", [
            sender,
            ethers.constants.Zero,
            accountABI.encodeFunctionData("transferNFT", [
              "0x33893e5a84758c93563513820d2fc5e6f41c8a04", //test mumbai nft contract
              ethers.constants.AddressZero,
              "0xeA32aDb911511d67e4F800c4e5FfD69755d738Fe",
              "1",
            ]),
          ]);
          // console.log(calldata);

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
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          const signer = new ethers.Wallet(process.env.PRIV_KEY, provider);
          const signature = await signer.signMessage(arraifiedHash);

          //send
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

          // await axios
          //   .request(options)
          //   .then((response) => {
          //     console.log(response.data);
          //   })
          //   .catch(function (error) {
          //     console.error(error);
          //   });
        });
        it("should not send SBT", async () => {
          await businessNFT.buyNft(0, {
            value: ethers.utils.parseEther("0.1"),
          });
          await businessNFT.transferFrom(
            deployer.address,
            accountContract.address,
            0
          );
          expect(async () => {
            await accountContract.transferNFT(
              businessNFT.address,
              businessNFT.address,
              deployer.address,
              0
            );
          }).to.be.revertedWith("Account__CANNOTSENDSBT");
        });
      });
    })
  : describe.skip;

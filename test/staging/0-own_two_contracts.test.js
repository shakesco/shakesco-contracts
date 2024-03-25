const { network, ethers } = require("hardhat");
const {
  mockOnThisNetworks,
  ENTRYPOINT,
} = require("../../helper-hardhat-config");
const { assert } = require("chai");
const fs = require("fs");
const axios = require("axios");

//Owner of account can own delegate,saving and autopayment!

mockOnThisNetworks.includes(network.name)
  ? describe("Multiowner", () => {
      let accContract,
        contractABI,
        savingsABI,
        contractFactoryABI,
        savingsFactoryABI,
        savingFactoryContract,
        entrypointABI,
        entrypointaccount,
        delegateFactoryContract,
        delegateFactoryABI,
        delegateABI,
        delegateContract,
        accFactoryContract;
      beforeEach(async () => {
        contractFactoryABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Factory/AccountFactory.sol/ShakescoAccountFactory.json",
            "utf8"
          )
        );

        entrypointABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/@account-abstraction/contracts/core/EntryPoint.sol/EntryPoint.json",
            "utf8"
          )
        );

        contractABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Users/Account.sol/ShakescoAccount.json",
            "utf8"
          )
        );
        const provider = new ethers.providers.JsonRpcProvider(
          process.env.MATICRPC_URL
        );

        const wallet = new ethers.Wallet(process.env.PRIV_KEY2, provider);
        const signer = await wallet.provider.getSigner(wallet.address);
        accContract = new ethers.Contract(
          "0x36850350BF94acE2490d94f10a6EAc52906F5909",
          contractABI.abi,
          provider
        );

        entrypointaccount = new ethers.Contract(
          ENTRYPOINT,
          entrypointABI.abi,
          provider
        );

        accFactoryContract = new ethers.Contract(
          "0x92B0E0bA11Ed57d10C1fc98C6C8a04340b2e5c99",
          contractFactoryABI.abi,
          provider
        );

        savingsABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Users/Savings.sol/ShakescoSavings.json",
            "utf8"
          )
        );

        savingContract = new ethers.Contract(
          "0xeb6FB481364BAc29B3F7A2126F674c47850d4C9e",
          savingsABI.abi,
          provider
        );

        savingsFactoryABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Factory/SavingsFactory.sol/ShakescoSavingsFactory.json",
            "utf8"
          )
        );

        savingFactoryContract = new ethers.Contract(
          "0x6FCA72D74114f8Dbf11fa08C69D1d09AEDDC061e",
          savingsFactoryABI.abi,
          provider
        );

        delegateFactoryABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Factory/DelegateFactory.sol/ShakescoDelegateAccountFactory.json",
            "utf8"
          )
        );

        delegateFactoryContract = new ethers.Contract(
          "0xCe9D807C591d875dec1e332339277fFD6E50C6fD",
          delegateFactoryABI.abi,
          provider
        );

        delegateABI = JSON.parse(
          fs.readFileSync(
            "./artifacts/contracts/Users/Delegate.sol/ShakescoDelegateAccount.json",
            "utf8"
          )
        );

        delegateContract = new ethers.Contract(
          "0x8c79650AfFc905ACF9Fa66781B3dBb16dCE6Ee42",
          delegateABI.abi,
          provider
        );
      });

      describe("get delegate account address", () => {
        it("compute delegate account", async () => {
          const address = await delegateFactoryContract.computeAddress(
            accContract.address,
            0
          );
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          //after deployment
          const code = await provider.getCode(address);
          assert(code.toString() > "0x");
          assert(address.toString() > "0x");
        });

        it("get request from delegate", async () => {
          const request = await delegateContract.isRequestOn();
          console.log(request.toString());
          assert.equal(request.toString(), "true");
        });
      });

      describe("deploy account", () => {
        it("should compute account address", async () => {
          const address = await accFactoryContract.computeAddress(
            "0xf765843BbD0230d512C2e29dc9b00E5EcdDBdDBb",
            0
          );
          //after deployment
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          const balance = await provider.getBalance(address);
          console.log(balance.toString());
          const code = await provider.getCode(address);
          assert(code.toString() > "0x");
        });
      });

      describe("get savings address", () => {
        it("should compute saving address", async () => {
          const address = await savingFactoryContract.computeAddress(
            accContract.address,
            10,
            ethers.utils.parseEther("0.0001"),
            300
          );
          console.log(address);
          assert(address > 0);
        });
      });

      describe("check savings deployment", () => {
        it("savings has been deployed", async () => {
          const address = await savingFactoryContract.computeAddress(
            accContract.address,
            10,
            ethers.utils.parseEther("0.0001"),
            300
          );
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          //after deployment
          const code = await provider.getCode(address);
          assert(code.toString() > "0x");
          console.log(code.toString());
        });

        it("get amount from saving contract", async () => {
          //remember we set amount as on deployment
          const toreach = ethers.utils.parseEther("0.0001");
          const amount = await savingContract.getAmountSet();
          const time = await savingContract.getTimePeriod();
          console.log(time.toString());
          console.log(amount.toString());
          console.log(toreach.toString());
          assert.equal(amount.toString(), toreach.toString());
        });
      });

      describe("Deploy saving", () => {
        it("Create saving account", async () => {
          const getnonce = (await accContract.getNonce()).toString();
          const sender = accContract.address;
          const nonce = `0x${getnonce}`;
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
          const savingABI = new ethers.utils.Interface(savingsFactoryABI.abi);

          const call = savingABI.encodeFunctionData("deploySaving", [
            sender,
            10,
            ethers.utils.parseEther("0.0001"),
            300,
          ]);

          const calldata = accountABI.encodeFunctionData("execute", [
            savingFactoryContract.address,
            ethers.constants.Zero,
            call,
          ]);
          // console.log("calldata :", calldata);

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
          const provider = new ethers.providers.JsonRpcProvider(
            process.env.MATICRPC_URL
          );
          const signer = new ethers.Wallet(process.env.PRIV_KEY2, provider);
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
          //   .then(function (response) {
          //     console.log(response.data);
          //   })
          //   .catch(function (error) {
          //     console.error(error);
          //   });
          // {
          //     id: 1,
          //     jsonrpc: '2.0',
          //     result: '0x0c67108f4b0364420f014790fbe8b3a61ef8ff405c62498d08ede0202cd2b738'
          //   }
        });
      });

      describe("Deploy delegate", () => {
        it("Create delegate account", async () => {
          const getnonce = (await accContract.getNonce()).toString();
          const sender = accContract.address;
          const nonce = `0x${getnonce}`;
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
          const delegate = new ethers.utils.Interface(delegateFactoryABI.abi);

          const call = delegate.encodeFunctionData("deployWallet", [sender, 0]);

          const calldata = accountABI.encodeFunctionData("execute", [
            delegateFactoryContract.address,
            ethers.constants.Zero,
            call,
          ]);
          // console.log("calldata :", calldata);

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
          //   .then(function (response) {
          //     console.log(response.data);
          //   })
          //   .catch(function (error) {
          //     console.error(error);
          //   });
          // {
          //     id: 1,
          //     jsonrpc: '2.0',
          //     result: '0x83ff089930371898321b1335fd16ffc7c595d4e749cc576f719c73631a397189'
          //   }
        });
      });
    })
  : describe.skip;

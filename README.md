# Shakesco Smartcontracts

- [Shakesco Smartcontracts](#shakesco-smartcontracts)
  - [Contracts](#contracts)
    - [Deploy](#deploy)
    - [Tests](#tests)

## Contracts

_Some contracts have not been open-sourced. This will be done in the coming weeks. Contracts are not available on Ethereum. This will also change in the coming weeks._

Here are the contracts addresses on Polygon:
  1. "FromShakesco.sol": "0x8BAF64Fc6b665cA46D0B5E4Eea81273e774E8f4c",
  2. "Account Factory": "0x12ea9e146902cBc0cbd6A205Dd99f88b3dbD321a",
  3. "Savings Factory": "0x00cebBCb1D599F7cDd4e429840E6d36f7b10f471",
  4. "Business Factory": "0x59D6951f45C89fC0f75294AE0D1823fF650621E1",
  5. "Business Token Factory": "0x28413C4618b7fD2d784BEBca21F6995085cacF53",
  6. "Business NFT Factory": "0xFddd49B619043fd2bB4C249f17DD28312A574713",
  7. "Business Saving Factory": "0x1beBa8543d6F9Fae233c0880f340A99e54c85E14",
  8. "Delegate Factory": "0x6d4A329eD234365ee49A9e1Dc6c31189606AA320",
  9. "Autopayment Factory": "0x8baBaa1D19859c5Dd615b4E49477601b2d133b45",
  10. "Business Delegate Factory": "0x8CA9Fe115Ea3BC5697475fB737871104282cc261",
  11. "Business Autopayment Factory": "0xaca39669bEBf65C934bEeb84ecD1bD842E6Bd3cf",
  12. "Username": "0x05CD28296aB1Df157667F8aB265D3A2ec187F82B",
  13. "Private": "0xc6e8b3a1938502e72080cBb288F30779bd795d43",
  14. "Register automation": "0x269d50b6d6770f1C21Da2bA205bC6609a61B5aC4",
  15. "Group Factory": "0x71F60c2bc1496ba21c2d3955C77E7796e439B778"

We have 6 folders that hold the main logic:

1. __Business__ - Holds the business logic for business accounts
2. __Factory__  - Holds contracts that will help users and business deploy their accounts(contracts)
3. __Mock__ - Just for testing purposes
4. __Shakesco__ - Holds contracts that shakesco offers to both businesses and indivisual
5. __Users__ - Holds logic for users accounts

---

### Deploy

---

We used hardhat for deployment. To learn more: [__Hardhat__](https://hardhat.org/tutorial "Hardhat Tutorial")

Contracts have been deployed on both mainnet and testnet.

- _Mumbai_ and _mainnet_ for __Polygon__
- _Sepolia_ and _mainnet_ for __Ethereum__

After cloning try:
> 💡Tip: Run `npm install` to add hardhat locally

```shell
npx hardhat deploy
```

For deployment on testnet or mainnet:

```shell
npx hardhat deploy --network <network of choice>
```


---

### Tests

---

Test had to be done in two ways to save cost:

- Tests done locally that don't require userop
- Test on useop have been done with [__Stackup__](https://docs.stackup.sh/docs "StackupAPI")
  
> 💡Tip: For this section you need api keys from either [__Alchemy__](https://www.alchemy.com/learn/account-abstraction "AlchemyAA") or [__StackUp__](https://docs.stackup.sh/docs "StackUpAA"). We recommend Stackup.

After getting your apikeys:

```shell
npx hardhat test
```


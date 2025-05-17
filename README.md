# Shakesco Smartcontracts

- [Shakesco Smartcontracts](#shakesco-smartcontracts)
  - [Contracts](#contracts)
    - [Deploy](#deploy)
    - [Tests](#tests)
    - [Features](#features)

Shakesco has built [__Shakesco__](https://shakesco.com/) an [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) smart wallet on Ethereum and Polygon. No seed phrases, Multi-party Computation(MPC), recurring payments, stealth payments, NFTs and tokens creation(Loyalty program), bound collectibles, built in marketplace and so much more! Our goal is to make Ethereum user-friendly and secure.

## Contracts

_Some contracts have not been open-sourced. This will be done in the coming weeks._

Here are the contracts addresses on Polygon:

  1. "FromShakesco.sol": "0x403302B37D2C29CA37f0b0BbCf1591F2dc2E7d22"
  2. "Account Factory": "0x12ea9e146902cBc0cbd6A205Dd99f88b3dbD321a"
  3. "Savings Factory": "0x00cebBCb1D599F7cDd4e429840E6d36f7b10f471"
  4. "Business Factory": "0x59D6951f45C89fC0f75294AE0D1823fF650621E1"
  5. "Business Token Factory": "0xAA5f01021CEe18A5dB1485ffC9D2CB3b823d0Dd7"
  6. "Business NFT Factory": "0x02A92c995c042eD9d2376E293233864e59B4322F"
  7. "Business Saving Factory": "0x1beBa8543d6F9Fae233c0880f340A99e54c85E14"
  8. "Delegate Factory": "0x19c74cfCD60297b4ae2c788FC74cF6B12aa27E5f"
  9. "Autopayment Factory": "0xbDd2647578712159Cb60cf57618d7B0ff99832f8"
  10. "Business Delegate Factory": "0xF9f3b28Ea1337eeF11943ee775161D7C109c4335"
  11. "Business Autopayment Factory": "0xa68Bc9Ce674692d94362A4567FE0Ca49408227BE"
  12. "Username": "0x3D134E5e7B8239AB76478B359092a988e69eE55e"
  13. "Private": "0x6238040aCf8daB04Cc26455934a9364e9Df2B950"
  14. "Register automation": "0xF4EA3CFE1470C0739600F4d57dA058d70C9e09c1"
  15. "Group Factory": "0x71F60c2bc1496ba21c2d3955C77E7796e439B778"
  16. "Swap": "0x59E3509Fa4f5228ea2a582533CC872eb9FB8B00A"
  
Here are the contracts addresses on Ethereum(Once that are not similar to Polygon):

  1. "FromShakesco.sol": "0x4CF0FB9086c63f0273997be5cB1275ebB123773F"
  2. "Delegate Factory": "0xdeBC6094634F4f75dF903abB5808d13dd8A68AEf"
  3. "Business Delegate Factory": "0x639A2b02159e78d1f033fEF8A488C9c5052eF2c0"
  4. "Business Autopayment Factory": "0xaca39669bEBf65C934bEeb84ecD1bD842E6Bd3cf"
  5. "Register automation": "0x9FD92917d2AE4d766b54cc103E0A4f38688F27A7"
  6. "Group Factory": "0xE859d17685Bf0D56F2b112ff7d0FCe2276E85545"
  7. "Swap": 0xa6E9774BF73753D8d019895Ec94E33F19A02d28b

Here are the contracts addresses on Base:
  1. "Account": "0x12ea9e146902cBc0cbd6A205Dd99f88b3dbD321a",
  2. "ACCOUNTUPGRADE": "0xE569781c018579859d69713510A4532bE91aDC37",
  3. "Business": "0x59D6951f45C89fC0f75294AE0D1823fF650621E1",
  4. "BUSINESSUPDATE": "0xF55C7594Ea8C7E442B93eF43a5c1eCEec1630316",
  5. "Token": "0x2C24cD31006d8195320F9ebb711fF3933D06202F",
  6. "NFT": "0xf290E4E8155E97D9c8f19705C632b2beAdb19A0D",
  7. "private": "0x6238040aCf8daB04Cc26455934a9364e9Df2B950",
  8. "stealth": "0xe18e9DF923aa82C3D7B593d657a653DBcc79B6e3",
  

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
- Test on useop have been done with [__Biconomy__](https://docs.biconomy.io/dashboard "BiconomyAPI")
  
> 💡Tip: For this section you need api keys from either [__Alchemy__](https://www.alchemy.com/learn/account-abstraction "AlchemyAA") or [__Biconomy__](https://docs.biconomy.io/dashboard "BiconomyAPI"). We recommend Stackup.

After getting your apikeys:

```shell
npx hardhat test
```

### Features

_Here we are going to cover exciting featues built by shakesco._

1. Buy, Send and receive/request - We have the basic features in every EOA wallet inside the wallet.
2. Recurring payments on Ethereum - We are excitted about this, you can now perform auto-payments on Ethereum. Check out our [documentation](https://docs.shakesco.com/docs/autopayments/integration/ "auto") on how it works and how you can start to receive auto-payments on Ethereum.
3. Private transaction - Credit to [umbra](https://github.com/ScopeLift/umbra-protocol/) we use their registry to register keys so that business and users can perform private transactions. Check out our [docs](https://docs.shakesco.com/docs/private/integration/ "private")
4. Send to many - ERC 4337 enables `executeBatch` function. You can send money to multiple people, or even privately send to multiple users.
5. Loyalty program - Business can deploy their own token or NFT and auction it off to the built in marketplace in the application. They can offer value, like discounted payments, rewards for reaching certain limits etc.
6. Name service - We developed a built in name service that enables anyone to register for free. Its a demand-based system rather than subscription based. So you can bid on usernames, preserve etc.
7. Group transaction - perform transactions as a group. Pay, send and add friends and family and enjoy your crypto journey together.
8. Personal accounts and business account integration - Open a personal wallet and then a business wallet and receive value in both.

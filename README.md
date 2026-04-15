# Shakesco Smart Contracts

- [Shakesco Smart Contracts](#shakesco-smart-contracts)
  - [Contracts](#contracts)
    - [Deploy](#deploy)
    - [Tests](#tests)
    - [Features](#features)

Shakesco has built [**Shakesco**](https://shakesco.com/) an [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) smart wallet on Ethereum and Polygon. No seed phrases, Multi-party Computation (MPC), recurring payments, private transactions, loyalty tokens, stealth addresses, and so much more! Our goal is to make Ethereum user-friendly and secure.

## Contracts

_Some contracts have not been open-sourced. This will be done in the coming weeks._

### Ethereum & Polygon

These contracts are deployed on both Ethereum and Polygon networks:

| Contract Name                 |                  Address                   |
| ----------------------------- | :----------------------------------------: |
| ShakescoAccountFactory        | 0x12ea9e146902cBc0cbd6A205Dd99f88b3dbD321a |
| ShakescoAccountFactoryUpdate  | 0x740a96bB998d40BE53321B4F4542dEA34Adc885d |
| ShakescoBusinessFactory       | 0x59D6951f45C89fC0f75294AE0D1823fF650621E1 |
| ShakescoBusinessFactoryUpdate | 0xF58668e9Fb0f7845F0b196613FBf37079E7c7Ccb |
| ShakescoPrivate               | 0xA7Be62548d08135f1f34fcf4881D35eBE649248a |
| StealthShakescoAccountFactory | 0xe18e9DF923aa82C3D7B593d657a653DBcc79B6e3 |

### Ethereum Only

These contracts are deployed only on Ethereum:

| Contract Name   |                  Address                   |
| --------------- | :----------------------------------------: |
| ShakescoAuction | 0x48abC05CA5e9b49592175c74A32220cAaC9508f3 |

### Polygon Only

These contracts are deployed only on Polygon:

| Contract Name                |                  Address                   |
| ---------------------------- | :----------------------------------------: |
| ShakescoBusinessTokenFactory | 0xa171836571fffD542A02a9f9651D9c49595038DE |
| ShakescoUsername             | 0x3D134E5e7B8239AB76478B359092a988e69eE55e |
| ShakescoTradeTokens          | 0x368214ae188430732FD23d4B938f342C39a28162 |
| ShakescoManageTokens         | 0xC45522975d38fE427bfC1a0ce02A2E2646f747E9 |

We have organized our contracts into logical folders:

1. **Business** - Business account logic and features
2. **Factory** - Contract deployment factories for users and businesses
3. **Mock** - Testing utilities
4. **Shakesco** - Core features for both businesses and individuals
5. **Users** - User account logic

---

### Deploy

---

We used Hardhat for deployment. To learn more: [**Hardhat**](https://hardhat.org/tutorial "Hardhat Tutorial")

Contracts have been deployed on both mainnet and testnet:

- _Amoy_ and _mainnet_ for **Polygon**
- _Sepolia_ and _mainnet_ for **Ethereum**

After cloning, try:

> 💡Tip: Run `npm install` to add Hardhat locally

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

Tests had to be done in two ways to optimize costs:

- Tests done locally that don't require UserOp
- Tests on UserOp have been done with [**Alchemy**](https://www.alchemy.com/docs/wallets/api-reference/bundler-api/bundler-api-endpoints/eth-send-user-operation "AlchemyAA")

> 💡Tip: For this section you need API keys from either [**Alchemy**](https://www.alchemy.com/docs/wallets/api-reference/bundler-api/bundler-api-endpoints/eth-send-user-operation "AlchemyAA") or [**Biconomy**](https://docs.biconomy.io/ "BiconomyAPI"). We recommend Alchemy.

After getting your API keys:

```shell
npx hardhat test
```

### Features

_Here we cover the exciting features built by Shakesco._

1. **Buy, Send and Receive/Request** - We have the basic features of every EOA wallet built into our smart contract wallets.

2. **Recurring Payments on Ethereum** - We're excited about this! You can now perform auto-payments on Ethereum. Check out our [documentation](https://docs.shakesco.com/auto-payments/ "auto-payments") on how it works and how you can start receiving auto-payments.

3. **Private Transactions** - Credit to [Umbra](https://github.com/ScopeLift/umbra-protocol/). We use their registry to register keys so that businesses and users can perform private transactions. Check out our [docs](https://docs.shakesco.com/stealth-payments/ "stealth-payments").

4. **Silent Payments** - Bitcoin Silent Payments implementation for enhanced privacy on Bitcoin transactions. See our [Silent Payments guide](https://docs.shakesco.com/silent-payments/ "silent-payments").

5. **Send to Many** - ERC-4337 enables the `executeBatch` function. You can send money to multiple people, or even privately send to multiple users at once.

6. **Loyalty Program** - Businesses can deploy their own ERC-20 loyalty tokens with advanced features:

   - **Token Creation** - Launch custom branded tokens
   - **Off-chain Management** - Customers don't need crypto wallets
   - **Staking** - Let customers lock tokens to earn rewards
   - **Vesting** - Distribute tokens gradually with cliff periods
   - **Cashback Programs** - Automatic rewards when spending thresholds are reached
   - **Happy Hours** - Limited-time promotions with multiplied rewards
   - **Tier Systems** - Bronze, Silver, Gold tiers based on holdings
   - **Daily Caps** - Control maximum daily earnings
   - **Voting Power** - Token-weighted governance

   See our [Loyalty Program documentation](https://docs.shakesco.com/loyalty-program/ "loyalty-program").

7. **Name Service** - We developed a built-in name service that enables anyone to register for free. It's a demand-based system rather than subscription-based. You can bid on usernames, preserve them, etc.

8. **Personal and Business Account Integration** - Open a personal wallet and then a business wallet and receive value in both. Seamlessly switch between personal and business contexts.

9. **Payment Links** - Create shareable payment links to accept one-time or recurring payments. Perfect for invoices, donations, or selling products.

10. **Checkout Integration** - Integrate crypto checkout into your website or app with simple APIs.

11. **Multi-Party Computation (MPC) Security** - Keys are distributed across multiple parties, ensuring no single point of failure. Enterprise-grade wallet security.

12. **Account Abstraction (ERC-4337)** - Gasless transactions, batch operations, and social recovery. Users don't need to manage gas fees or seed phrases.

13. **Cross-Chain Support** - Support for Ethereum, Polygon, Arbitrum, Optimism, Base, BSC, and Bitcoin Lightning Network.

14. **Marketplace** - Built-in marketplace for businesses to auction loyalty tokens and NFTs to customers.

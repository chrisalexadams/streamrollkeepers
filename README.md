# StreamRoll Finance

* Superfluid Implementation not in this repo.
* `CloneFactory.sol` is not implemented.

## Installation

1. Copy `.env.example` to a new `.env` file and fill in your credentials.

2. `npm i`

3. `npx hardhat compile`

4. `npx hardhat run scripts/deploy.js --network kovan`

5. `npx hardhat verify --network kovan DEPLOYED_CONTRACT_ADDRESS` -> Need to verify the contract in order to register a keeper.

6. Go to the [Keepers page](https://keepers.chain.link/) 

7. Use the deployed address on kovan as the `Upkeep Address`

8. Gas limit: 200000

9. Fund at least 30 LINK

# Overview

FoxLottery is a blockchain lottery using crypto assets and smart contracts.

It is intended for use by municipalities that conduct lotteries around the world.

You can start a lottery immediately by setting the lottery return rate, the ERC20 tokens to be used as criteria, and the lottery cycle.

The ERC20 tokens collected from users will be distributed to random winners.

# Setup

## module install
```
yarn install
```

## start local node
```
npx hardhat node
```

## test
```
npx hardhat test test/hardhat/RandomValueGeneratorMock.ts
npx hardhat test test/hardhat/Lottery.ts
npx hardhat test test/hardhat/TestUSD.ts
```

## local net deploy
```
npx hardhat run --network localhost scripts/TestUSD/deploy.ts
npx hardhat run --network localhost scripts/Lottery/deploy.ts
```

## test net deploy
```
npx hardhat run --network rinkeby scripts/Lottery/deploy.ts
npx hardhat run --network mumbai scripts/Lottery/deploy.ts
npx hardhat run --network binanceSmartCahinTestnet scripts/Lottery/deploy.ts
npx hardhat run --network avalancheFuji scripts/Lottery/deploy.ts
```

# White Paper
[White Paper](https://cryptolottery.gitbook.io/cryptolottery-whitepaper/whitepaper/english)

[ホワイトペーパー](https://cryptolottery.gitbook.io/cryptolottery-whitepaper/whitepaper/japanese)

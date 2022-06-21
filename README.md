# Overview
### English
FoxLottery is a blockchain lottery using crypto assets and smart contracts.

It is intended for use by municipalities that conduct lotteries around the world.

You can start a lottery immediately by setting the lottery return rate, the ERC20 tokens to be used as criteria, and the lottery cycle.

The ERC20 tokens collected from users will be distributed to random winners.

### 日本語
FoxLotteryは暗号資産とスマートコントラクトを使用したブロックチェーン宝くじです。

世界中の宝くじをする自治体が、使用することを想定しています。

宝くじの還元率や基準にするERC20トークン、宝くじのサイクルを設定して、すぐに宝くじを始めることができます。

ユーザーから収集したERC20トークンをランダムな当せん者に分配します。

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
npx hardhat test test/hardhat/TokenTimedRandomSendContract.ts
npx hardhat test test/hardhat/LotteryERC20.ts
```

## local net deploy
```
npx hardhat run --network localhost scripts/LotteryERC20/deploy.ts
npx hardhat run --network localhost scripts/TokenTimedRandomSendContract/deploy.ts
```

## test net deploy
```
npx hardhat run --network rinkeby scripts/TokenTimedRandomSendContract/deploy.ts
npx hardhat run --network mumbai scripts/TokenTimedRandomSendContract/deploy.ts
npx hardhat run --network binanceSmartCahinTestnet scripts/TokenTimedRandomSendContract/deploy.ts
npx hardhat run --network avalancheFuji scripts/TokenTimedRandomSendContract/deploy.ts
```

# White Paper
[White Paper](https://cryptolottery.gitbook.io/cryptolottery-whitepaper/whitepaper/english)

[ホワイトペーパー](https://cryptolottery.gitbook.io/cryptolottery-whitepaper/whitepaper/japanese)

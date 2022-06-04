# Overview
### English
CryptoLottery is a decentralized lottery using crypto assets.
ERC20 tokens collected from users are distributed to random winners.
When users send money to the lottery, they can choose where to donate it, and a portion of the lottery proceeds are used for non-profit activities as determined by a vote.

While regular lotteries offer a return rate of about 50%, the
CryptoLottery will return 75% to users, 5% to affiliate users and the remaining 15% to revenue and 5% to non-profit expenses.

Translated with www.DeepL.com/Translator (free version)

### 日本語
CryptoLotteryは暗号資産とスマートコントラクト使用した分散型宝くじです。
ユーザーから収集したERC20トークンをランダムな当選者に分配します。
ユーザーは宝くじに送金する時に、寄付先を選択でき、宝くじの収益の一部を投票によって決めた非営利活動に使います。

通常の宝くじでは、還元率が50%ほどですが、
CryptoLotteryでは、ユーザーへの還元率を75%にして、アフィリエイトユーザーに5％、残り15%を収益、非営利活動費を5%にします。

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
npx hardhat test
```

## local net deploy
```
npx hardhat run --network localhost scripts/hardhat/deploy.ts
```

## test net deploy
```
npx hardhat run --network ropsten scripts/deploy.ts
```

# White Paper
[White Paper](https://cryptolottery.gitbook.io/cryptolottery-whitepaper/whitepaper/english)

[ホワイトペーパー](https://cryptolottery.gitbook.io/cryptolottery-whitepaper/whitepaper/japanese)

# CryptoLottery

# Overview
CryptoLottery is a decentralized lottery using crypto assets.
ERC20 tokens collected from users are distributed to random winners.
Users can choose where to donate when sending money to the lottery, and a portion of the lottery proceeds are used for non-profit activities as determined by a vote.

While regular lotteries offer a return rate of about 50%, the
CryptoLottery will return 75% to users, 5% to affiliate users, the remaining 15% to revenue, and 5% to non-profit expenses.

# Marketing Strategy
Give away free lottery tickets to users who retweet or follow you on Twitter without having to buy a CryptoLottery lottery ticket.

# Centralized Lottery Challenges
- Lack of transparency
- Low distribution rate
- A portion of profits are used to contribute to society, but there is a centralized decision on where to donate
- Large amount of money spent on sales promotion

# Solutions and functions that solve problems
## Transparent winner determination
Random numbers are generated on the blockchain, so winners can be determined transparently.

## High distribution ratio
By making it a DAO, the budget is easier to collect, and because it is done on the blockchain, there is less budget for server costs, etc. Affiliate functionality provides an incentive for referrals, keeping marketing costs low.

! [](docs/img/sharing_ratio.png)

## Affiliates
5% of the amount of lottery tickets purchased is paid to the affiliate as an affiliate commission. If not through an affiliate, the funds are paid to the CryptoLottery management.
Therefore, the lottery participant pays the same amount of money whether he/she participates via an affiliate or directly from the CryptoLottery management's website.

## DAO-ization
Governance token holders can decide where to donate, set policies, and receive a portion of the proceeds.
The owner organization handles marketing activities and development.

## Usage
You can purchase CryptoLottery tokens on exchanges or DeFi and
There are daily, weekly, monthly, and yearly CryptoLottery smart contracts, so you can deposit funds into the one you want.
Once you have deposited your funds, you can check to see how likely you are to win, if at all.

## Which blockchain networks can I use it on?
Since it is developed in Solidity, it can be used with Ethereum, Binance, Polygon, Astar Network, Avalanche, etc.

## Technical Specifications
Solidity
Hardhat
Alchemy

## Mechanisms to ensure randomness
It is difficult to guarantee randomness in Solidity. This is because there is no Rand function in Solidity, since all blockchain nodes return the same value.
Therefore, we created the following alternative random function.
No user will know the address of the participant, the participant's midpoint, or how much ERC20 will be collected in total until the deadline arrives.

````
((number of participants + block tomstamp (current time) + address of user at midpoint of number of participants) % number of participants) + amount of ERC20 gathered) % number of participants
````

This type of mechanism can be used to ensure randomness.

## Winning amount simulation

! [](docs/img/money_won.png)

# Concerns
Japanese law definitely does not allow this service to operate, so it is necessary to consider which country to base it in.


Translated with www.DeepL.com/Translator (free version)
# TRST

# Overview
TRST stands for Timed Random Send Token, which translates directly to Timed Random Send Token, which is a random token collected from users at a specific time according to a time cycle and distribution ratio determined by the smart contract owner. The distribution can be made to the winners.

TRST will give 75% back to users, 15% to revenue and 10% to non-profit activities: 10%.

# Marketing Strategy
Recurring those who retweet and follow as having bought one TRST token, so that they can participate in TRST without having to lock up their funds.

# Centralized Lottery Challenges
- Lack of transparency
- Low distribution rate
- A portion of the profits are used to contribute to society, but there is a centralized decision on where to donate the money
- Many amounts lack sales promotion

# Solutions/features that solve problems
## Transparent winner determination
Random numbers are generated on the blockchain, so winners can be determined transparently

## High distribution rate
By making it a DAO, the budget is easier to collect, and because it is done on the blockchain, there is less budget for server costs, etc. Affiliate functionality provides an incentive for referrals, keeping marketing costs low.

! [](docs/img/sharing_ratio.png)

## Affiliates
5% of funds locked into TRST's smart contract as an affiliate commission, payable If not through an affiliate, the funds are paid to TRST management.
Therefore, TRST participants pay the same cost whether they join through an affiliate or directly from the TRST management website.

## DAO-ization
Governance token holders get to decide where to donate, set policy, and get a portion of the proceeds.
Owner organization handles marketing activities and development

## Usage
You can purchase TRST Dao tokens on exchanges or DeFi and
There are daily, weekly, monthly, and yearly TRST smart contracts, so lock your funds into whatever you want.
Once you lock your funds, you can see how likely you are to win, if at all.

## Which blockchain networks can I use it on?
Developed in Solidity, so can be released on Ethereum, Binance, Polygon, Astar Network, Avalanche, etc.

## Technical specifications
Solidity
Hardhat
Alchemy

## Mechanism to ensure randomness
It is difficult to guarantee randomness in Solidity. This is because there is no Rand function in Solidity, since all blockchain nodes return the same value.
Therefore, we created the following alternative random function.
No user will know the address of the participant, the participant's midpoint, or how much ERC20 will be collected in total until the deadline arrives.

````
((number of participants + block tomstamp (current time) + address of user at midpoint of number of participants) % number of participants) + amount of ERC20 gathered) % number of participants
````

This type of mechanism can be used to ensure randomness.

## Winning amount simulation

! [](docs/img/money_won.png)

# Concerns.
It is necessary to consider whether it is better to separate the governor's tokens from the ERC20 tokens used for TRST.
Need to consider which country to base it in to do this, as this service definitely cannot be operated under Japanese law

Translated with www.DeepL.com/Translator (free version)

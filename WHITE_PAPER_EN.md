# TRST

# Overview
TRST stands for Timed Random Send Token, which translates directly to Timed Random Send Token, which is a random token collected from users at a specific time according to a time cycle and distribution ratio determined by the smart contract owner. The distribution can be made to the winners.

TRST Dao will give 75% back to users, 5% to affiliate users, and the remaining 15% to revenue and 5% to non-profit expenses.

# Marketing Strategy
Allow people who retweet TRST DAO event tweets and follow TRST DAO accounts to participate in TRST without having to buy TRST DAO tokens in order to attend the event.

# Centralized Lottery Challenges
- Lack of transparency
- Low distribution rate
- A portion of the profits are used to contribute to society, but there is a centralized decision on where to donate the money
- Large amount of money spent on sales promotion

# Solutions and functions that solve problems
## Transparent winner determination
Random numbers are generated on the blockchain, so winners can be determined transparently.

## High distribution ratio
By making it a DAO, the budget is easier to collect, and because it is done on the blockchain, there is less budget for server costs, etc. Affiliate functionality provides an incentive for referrals, keeping marketing costs low.

! [](docs/img/sharing_ratio.png)

## Affiliates
5% of funds locked into TRST's smart contract as an affiliate commission, payable If not through an affiliate, the funds are paid to TRST management.
So the cost paid by TRST participants will be the same whether they participate through an affiliate or directly from the TRST management website.

## DAO-ization
Governance token holders can decide where to donate, set policy, and get a portion of the proceeds.
The owner organization handles marketing activities and development.

## Usage
You can buy TRST Dao tokens on exchanges or DeFi and
There are daily, weekly, monthly, and yearly TRST smart contracts, so you can lock your funds into whatever you want.
Once you lock in your funds, you can see how likely you are to win, if at all.

## Which blockchain networks can I use it on?
Since it is developed in Solidity, it can be released on Ethereum, Binance, Polygon, Astar Network, Avalanche, etc.

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

// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers, network } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import getConfig from "../config";

const networkName = network.name;
const config = getConfig(networkName);

async function main() {
  if (config === undefined) {
    console.log("require set config: ", networkName);
    return;
  }

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  const ERC20Contract = await ethers.getContractFactory("ERC20");
  const ERC20 = await ERC20Contract.attach(
    config.ERC20Address // The deployed contract address
  );
  const deployerTokenAmount = await ERC20.balanceOf(deployer.address);

  console.log("ERC20 Account balance:", deployerTokenAmount);

  const tokenTimedRandomSendContractFactory = await ethers.getContractFactory(
    "TokenTimedRandomSendContract"
  );

  let tokenTimedRandomSendContract;
  if (config.tokenTimedRandomSendContract !== null) {
    tokenTimedRandomSendContract =
      await tokenTimedRandomSendContractFactory.attach(
        config.tokenTimedRandomSendContract
      );
  } else {
    tokenTimedRandomSendContract =
      await tokenTimedRandomSendContractFactory.deploy(
        config.name,
        config.symbol,
        ERC20.address,
        config.ticketPrice,
        config.isOnlyOwner,
        config.cycle,
        config.closeTimestamp,
        config.subscriptionId,
        config.vrfCoordinator,
        config.keyHash
      );
  }

  await tokenTimedRandomSendContract.deployed();
  console.log("setSellerCommissionRatio: ", config.sellerCommissionRatio);
  await tokenTimedRandomSendContract.setSellerCommissionRatio(
    config.sellerCommissionRatio
  );

  // set rule
  for (const rule of config.randomSendingRules) {
    setTimeout(() => null, 3000);
    console.log(rule);
    await tokenTimedRandomSendContract.createRandomSendingRule(
      rule.raito,
      rule.sendingCount
    );
  }

  await tokenTimedRandomSendContract.createDefinitelySendingRule(
    1 / 0.1, // 10%
    deployer.address // owner
  );

  await tokenTimedRandomSendContract.complatedRuleSetting();
  await tokenTimedRandomSendContract.statusToAccepting();
  console.log(
    "tokenTimedRandomSendContract contract: ",
    tokenTimedRandomSendContract.address
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

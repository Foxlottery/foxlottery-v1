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
const sleep = (waitTime: any) =>
  new Promise((resolve) => setTimeout(resolve, waitTime));

async function main() {
  if (config === undefined) {
    console.log("require set config:", networkName);
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

  const lotteryFactory = await ethers.getContractFactory("Lottery");
  const randomValueGeneratorFactory = await ethers.getContractFactory(
    "RandomValueGenerator"
  );

  let lottery;
  if (config.lottery !== null) {
    lottery = await lotteryFactory.attach(config.lottery);
  } else {
    console.log("start lottery deploy");
    lottery = await lotteryFactory.deploy(
      config.name,
      config.symbol,
      ERC20.address,
      config.ticketPrice,
      config.cycle,
      config.closeTimestamp
    );
    await lottery.deployed();
    await sleep(5000);
    console.log("start random value generator deploy");
    const randomValueGenerator = await randomValueGeneratorFactory.deploy(
      lottery.address,
      config.subscriptionId,
      config.vrfCoordinator,
      config.keyHash
    );
    await randomValueGenerator.deployed();
    await sleep(15000);
    console.log("set random value generator to lottery");
    await lottery.setRandomValueGenerator(randomValueGenerator.address);
  }
  await sleep(15000);

  console.log("setSellerCommissionRatio:", config.sellerCommissionRatio);
  await lottery.setSellerCommissionRatio(config.sellerCommissionRatio);

  // set rule
  for (const rule of config.randomSendingRules) {
    await sleep(15000);
    console.log(rule);
    await lottery.createRandomSendingRule(rule.raito, rule.sendingCount);
  }

  await sleep(15000);
  console.log("createDefinitelySendingRule");
  await lottery.createDefinitelySendingRule(
    1 / 0.2, // 20%
    deployer.address // owner
  );

  await sleep(15000);
  console.log("complatedRuleSetting");
  await lottery.complatedRuleSetting();
  await sleep(15000);
  console.log("statusToAccepting");
  await lottery.statusToAccepting();
  console.log("lottery contract:", lottery.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

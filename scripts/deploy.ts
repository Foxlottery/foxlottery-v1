// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Greeter = await ethers.getContractFactory("Greeter");
  const greeter = await Greeter.deploy("Hello, Hardhat!");

  await greeter.deployed();

  console.log("Greeter deployed to:", greeter.address);

  const LotteryToken = await ethers.getContractFactory("LotteryToken");
  const WeeklyLottery = await ethers.getContractFactory("WeeklyLottery");
  const lotteryToken = await LotteryToken.deploy();
  const weeklyLottery = await WeeklyLottery.deploy(lotteryToken.address);
  const signers = await ethers.getSigners();
  const owner = signers[0];
  lotteryToken.mint(owner.address, "100");

  // add Win Rule
  weeklyLottery.connect(owner).addWinRule(0.25 * 10 ** 10, 1); // There's a 25% chance 1 of us will win.
  weeklyLottery.connect(owner).addWinRule(0.05 * 10 ** 10, 2); // There's a 5% chance 2 of us will win.
  weeklyLottery.connect(owner).addWinRule(0.01 * 10 ** 10, 5); // There's a 1% chance 5 of us will win.
  weeklyLottery.connect(owner).addWinRule(0.005 * 10 ** 10, 20); // There's a 0.5% chance 20 of us will win.
  weeklyLottery.connect(owner).addWinRule(0.0001 * 10 ** 10, 2000); // There's a 0.01% chance 2000 of us will win.
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

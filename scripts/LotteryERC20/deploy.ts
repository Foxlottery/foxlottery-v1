// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  const lotteryERC20Contract = await ethers.getContractFactory("LotteryERC20");
  const lotteryERC20 = await lotteryERC20Contract.deploy();
  await lotteryERC20.deployed();
  const tokenPrice = ethers.BigNumber.from("5000000000000000000000");
  await lotteryERC20.mint(deployer.address, tokenPrice);
  const deployerTokenAmount = await lotteryERC20.balanceOf(deployer.address);
  console.log("lotteryERC20 contract: ", lotteryERC20.address);
  console.log("LotteryERC20 Account balance:", deployerTokenAmount);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

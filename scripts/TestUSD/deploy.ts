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
  const TestUSDContract = await ethers.getContractFactory("TestUSD");
  const TestUSD = await TestUSDContract.deploy();
  await TestUSD.deployed();
  const tokenPrice = ethers.BigNumber.from("5000000000000000000000");
  await TestUSD.mint(deployer.address, tokenPrice);
  const deployerTokenAmount = await TestUSD.balanceOf(deployer.address);
  console.log("TestUSD contract: ", TestUSD.address);
  console.log("TestUSD Account balance:", deployerTokenAmount);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

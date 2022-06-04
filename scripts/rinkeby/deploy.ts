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

  const _link = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709";
  const _coordinator = "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B";
  const _keyHash =
    "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311";

  const CryptoLottery = await ethers.getContractFactory("CryptoLottery");
  const WeeklyCryptoLottery = await ethers.getContractFactory(
    "TimedRandomSendContract"
  );
  const cryptoLottery = await CryptoLottery.deploy();
  const weeklyCryptoLottery = await WeeklyCryptoLottery.deploy(
    "WeeklyCryptoLottery",
    "WLT",
    60, // 1 minits cycle
    cryptoLottery.address,
    _link,
    _coordinator,
    _keyHash
  );

  await weeklyCryptoLottery.createRandomSendingRule(1 / 0.0001, 2000);
  await weeklyCryptoLottery.createRandomSendingRule(1 / 0.005, 20);
  await weeklyCryptoLottery.createRandomSendingRule(1 / 0.01, 5);
  await weeklyCryptoLottery.createRandomSendingRule(1 / 0.05, 2);
  await weeklyCryptoLottery.createRandomSendingRule(1 / 0.25, 1);

  if (process.env.MAIN_ACCOUNT_ADDRESS) {
    await cryptoLottery.mint(
      process.env.MAIN_ACCOUNT_ADDRESS,
      "10000000000000000000000"
    );
  }

  console.log("cryptoLottery: ", cryptoLottery.address);
  console.log("weeklyCryptoLottery: ", weeklyCryptoLottery.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

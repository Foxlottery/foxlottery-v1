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
    86400 * 7,
    cryptoLottery.address,
    _link,
    _coordinator,
    _keyHash
  );

  // const randomSendingRules = [
  //   { raito: 1 / 0.0001, sendingCount: 2000 }, // There's a 0.01% chance 2000 of us will win.
  //   { raito: 1 / 0.005, sendingCount: 20 }, // There's a 0.5% chance 20 of us will win.
  //   { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
  //   { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
  //   { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
  // ];
  const ratio = 1 / 0.0001;
  const sendingCount = 200;

  await weeklyCryptoLottery.setRandomSendingRule(ratio, sendingCount);

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

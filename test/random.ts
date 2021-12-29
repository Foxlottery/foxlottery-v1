import { expect } from "chai";
import { ethers } from "hardhat";

describe("random", function () {
  before(async function () {
    this.LotteryToken = await ethers.getContractFactory("LotteryToken");
    this.WeeklyLottery = await ethers.getContractFactory("TRST");
    this.signers = await ethers.getSigners();
  });

  beforeEach(async function () {
    this.lotteryToken = await this.LotteryToken.deploy();
    this.weeklyLottery = await this.WeeklyLottery.deploy(
      "WeeklyLottery",
      "WLT",
      70,
      this.lotteryToken.address
    );

    // set rule
    const randomSendingRules = [
      { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
      { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
      { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
    ];
    randomSendingRules.forEach(async (rule) => {
      await this.weeklyLottery.setRandomSendingRule(
        rule.raito,
        rule.sendingCount
      );
    });

    // buy weekly token
    this.signers.forEach((user: any) => {
      this.lotteryToken.mint(user.address, "100");
      this.lotteryToken
        .connect(user)
        .approve(this.weeklyLottery.address, "100");
      this.weeklyLottery.connect(user).buy("100");
    });

    this._sleep = (ms: number) =>
      new Promise((resolve) => setTimeout(resolve, ms));
  });

  it("randSend", async function () {
    await this._sleep(10000); // 10 seconds later
    this.weeklyLottery.randSend();
  });
});

import { ethers } from "hardhat";

describe("random", function () {
  before(async function () {
    this.CryptoLottery = await ethers.getContractFactory("CryptoLottery");
    this.WeeklyCryptoLottery = await ethers.getContractFactory(
      "TimedRandomSendContract"
    );
    this.signers = await ethers.getSigners();
    console.log(this.signers.length);
  });

  beforeEach(async function () {
    this.cryptoLottery = await this.CryptoLottery.deploy();
    this.weeklyCryptoLottery = await this.WeeklyCryptoLottery.deploy(
      "WeeklyCryptoLottery",
      "WLT",
      120,
      this.cryptoLottery.address
    );

    // set rule
    const randomSendingRules = [
      { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
      { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
      { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
    ];
    randomSendingRules.forEach(async (rule) => {
      await this.weeklyCryptoLottery.setRandomSendingRule(
        rule.raito,
        rule.sendingCount
      );
    });

    // buy weekly token
    this.signers.forEach((user: any) => {
      this.cryptoLottery.mint(user.address, "100");
      this.cryptoLottery
        .connect(user)
        .approve(this.weeklyCryptoLottery.address, "100");
      this.weeklyCryptoLottery.connect(user).buy("100");
    });
  });

  it("randSend", async function () {
    this.weeklyCryptoLottery.randSend();
  });
});

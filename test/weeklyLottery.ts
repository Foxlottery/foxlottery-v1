import { expect } from "chai";
import { ethers } from "hardhat";

describe("WeeklyLottery", function () {
  before(async function () {
    this.LotteryToken = await ethers.getContractFactory("LotteryToken");
    this.WeeklyLottery = await ethers.getContractFactory("TRST");

    this.signers = await ethers.getSigners();
    this.owner = this.signers[0];
    this.bob = this.signers[1];
    this.carol = this.signers[2];
  });

  beforeEach(async function () {
    this.lotteryToken = await this.LotteryToken.deploy();
    this.weeklyLottery = await this.WeeklyLottery.deploy(
      "WeeklyLottery",
      "WLT",
      86400 * 7,
      this.lotteryToken.address
    );

    const randomSendingRules = [
      { raito: 1 / 0.0001, sendingCount: 2000 }, // There's a 0.01% chance 2000 of us will win.
      { raito: 1 / 0.005, sendingCount: 20 }, // There's a 0.5% chance 20 of us will win.
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
    this.lotteryToken.mint(this.owner.address, "100");
    this.lotteryToken.mint(this.bob.address, "100");
    this.lotteryToken.mint(this.carol.address, "100");
  });

  it("should have correct name and symbol and decimal", async function () {
    const name = await this.lotteryToken.name();
    const symbol = await this.lotteryToken.symbol();
    const decimals = await this.lotteryToken.decimals();
    expect(name, "WeeklyLottery");
    expect(symbol, "WLT");
    expect(decimals, "18");
  });

  it("setDefinitelySendingRule", async function () {
    await this.weeklyLottery.setDefinitelySendingRule(
      1 / 0.2,
      this.lotteryToken.address
    );
    const definitelySendingRule =
      await this.weeklyLottery.definitelySendingRules(0);
    expect(definitelySendingRule.ratio).to.equal(1 / 0.2);
    expect(definitelySendingRule.destinationAddress).to.equal(
      this.lotteryToken.address
    );
  });

  it("deleteDefinitelySendingRule", async function () {
    await this.weeklyLottery.setDefinitelySendingRule(
      1 / 0.2,
      this.lotteryToken.address
    );
    await this.weeklyLottery.setDefinitelySendingRule(
      1 / 0.02,
      this.lotteryToken.address
    );
    await this.weeklyLottery.deleteDefinitelySendingRule(0);
    const definitelySendingRule =
      await this.weeklyLottery.definitelySendingRules(0);
    expect(definitelySendingRule.ratio).to.equal(1 / 0.02);
  });

  it("lottryTokenを持っていること", async function () {
    expect(await this.lotteryToken.balanceOf(this.owner.address)).to.equal(
      "100"
    );
    expect(await this.lotteryToken.balanceOf(this.bob.address)).to.equal("100");
    expect(await this.lotteryToken.balanceOf(this.carol.address)).to.equal(
      "100"
    );
  });

  it("getNumber", async function () {
    await this.lotteryToken
      .connect(this.bob)
      .approve(this.weeklyLottery.address, "100");
    await this.weeklyLottery.connect(this.bob).buy("100");
    console.log(await this.weeklyLottery.getNumber(1));
  });

  it("getRand", async function () {
    await this.lotteryToken
      .connect(this.bob)
      .approve(this.weeklyLottery.address, "100");
    await this.weeklyLottery.connect(this.bob).buy("100");
    console.log(await this.weeklyLottery.getRand());
  });

  it("buy lotteryTokenが足りないと、weeklyLottery購入ができないこと", async function () {
    await expect(
      this.weeklyLottery.connect(this.bob).buy("200")
    ).to.be.revertedWith("");
    expect(await this.weeklyLottery.totalSupply()).to.equal("0");
    expect(await this.weeklyLottery.balanceOf(this.bob.address)).to.equal("0");
  });

  it("buy lotteryTokenがあると、weeklyLottery購入ができること、かつlotteryTokenが減っていること、かつ参加者に追加されていること", async function () {
    await this.lotteryToken
      .connect(this.bob)
      .approve(this.weeklyLottery.address, "100");
    await this.weeklyLottery.connect(this.bob).buy("100");
    expect(await this.weeklyLottery.totalSupply()).to.equal("100");
    expect(await this.weeklyLottery.balanceOf(this.bob.address)).to.equal(
      "100"
    );
    const participant = await this.weeklyLottery.participants(0);
    expect(participant).to.equal(this.bob.address);
  });

  describe("withdraw", function () {
    it("weeklyTokenが足りないと返却できないこと", async function () {
      await this.lotteryToken.approve(this.bob.address, "100");
      await expect(
        this.weeklyLottery.connect(this.bob).withdraw("100")
      ).to.be.revertedWith("");
      expect(await this.weeklyLottery.totalSupply()).to.equal("0");
      expect(await this.weeklyLottery.balanceOf(this.bob.address)).to.equal(
        "0"
      );
    });

    it("weeklyTokenがあれば、返却できること", async function () {
      // buy
      await this.lotteryToken
        .connect(this.bob)
        .approve(this.weeklyLottery.address, "100");
      await this.weeklyLottery.connect(this.bob).buy("100");
      expect(await this.weeklyLottery.balanceOf(this.bob.address)).to.equal(
        "100"
      );

      // withdraw
      await this.weeklyLottery.connect(this.bob).withdraw("100");
      expect(await this.weeklyLottery.totalSupply()).to.equal("0");
      expect(await this.weeklyLottery.balanceOf(this.bob.address)).to.equal(
        "0"
      );
    });
  });

  it("currentRandomSendingTotalが70%であること", async function () {
    expect(
      (await this.weeklyLottery.currentRandomSendingTotal()) / 10 ** 18
    ).to.equal(0.7);
  });

  it("deleteRandomSendintRule RandomSendintRulesが削除できること", async function () {
    expect(
      (await this.weeklyLottery.currentRandomSendingTotal()) / 10 ** 18
    ).to.equal(0.7);
    await this.weeklyLottery.deleteRandomSendintRule(0);
    expect(
      (await this.weeklyLottery.currentRandomSendingTotal()) / 10 ** 18
    ).to.equal(0.5);
  });

  it("deleteRandomSendintRule and setRandomSendingRule 再度RandomSendintRulesを設定できること", async function () {
    expect(
      (await this.weeklyLottery.currentRandomSendingTotal()) / 10 ** 18
    ).to.equal(0.7);
    await this.weeklyLottery.deleteRandomSendintRule(0);
    expect(
      (await this.weeklyLottery.currentRandomSendingTotal()) / 10 ** 18
    ).to.equal(0.5);
    await this.weeklyLottery.setRandomSendingRule(1 / 0.0001, 2000);
    expect(
      (await this.weeklyLottery.currentRandomSendingTotal()) / 10 ** 18
    ).to.equal(0.7);
  });

  describe("canChangeRuleByTime: 時間が過ぎている場合、さらにrandomSendRuleを追加できないこと", function () {
    beforeEach(async function () {
      this.lotteryToken = await this.LotteryToken.deploy();
      this.weeklyLottery = await this.WeeklyLottery.deploy(
        "WeeklyLottery",
        "WLT",
        10,
        this.lotteryToken.address
      );
      this.signers.forEach((user: any) => {
        this.lotteryToken.mint(user.address, "100");
        this.lotteryToken
          .connect(user)
          .approve(this.weeklyLottery.address, "100");
        this.weeklyLottery.connect(user).buy("100");
      });
    });

    it("エラーが出ること", async function () {
      await setTimeout(async () => {
        await expect(
          this.weeklyLottery.setRandomSendingRule(4, 1)
        ).to.be.revertedWith(
          "TRST: Rule changes can be made up to one-tenth of the end time."
        );
      }, 4000);
    });
  });

  describe("canSetDefinitelySendingRules: 100％を越してしまう場合", function () {
    beforeEach(async function () {
      this.lotteryToken = await this.LotteryToken.deploy();
      this.weeklyLottery = await this.WeeklyLottery.deploy(
        "WeeklyLottery",
        "WLT",
        86400 * 7,
        this.lotteryToken.address
      );
      this.signers.forEach((user: any) => {
        this.lotteryToken.mint(user.address, "100");
        this.lotteryToken
          .connect(user)
          .approve(this.weeklyLottery.address, "100");
        this.weeklyLottery.connect(user).buy("100");
      });

      const randomSendingRules = [
        { raito: 1 / 0.0001, sendingCount: 2000 }, // There's a 0.01% chance 2000 of us will win.
        { raito: 1 / 0.005, sendingCount: 20 }, // There's a 0.5% chance 20 of us will win.
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
    });

    it("エラーが出ること", async function () {
      await expect(
        this.weeklyLottery.setDefinitelySendingRule(
          1 / 0.5,
          this.lotteryToken.address
        )
      ).to.be.revertedWith("TRST: Only less than 100%");
    });
  });
});

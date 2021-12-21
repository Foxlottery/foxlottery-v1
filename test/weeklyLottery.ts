import { expect } from "chai";
import { ethers } from "hardhat";

describe("WeeklyLottery", function () {
  before(async function () {
    this.LotteryToken = await ethers.getContractFactory("LotteryToken");
    this.WeeklyLottery = await ethers.getContractFactory("WeeklyLottery");

    this.signers = await ethers.getSigners();
    this.owner = this.signers[0];
    this.bob = this.signers[1];
    this.carol = this.signers[2];
  });

  beforeEach(async function () {
    this.lotteryToken = await this.LotteryToken.deploy();
    this.weeklyLottery = await this.WeeklyLottery.deploy(
      this.lotteryToken.address
    );
    this.lotteryToken.mint(this.owner.address, "100");
    this.lotteryToken.mint(this.bob.address, "100");
    this.lotteryToken.mint(this.carol.address, "100");

    // add Win Rule
    this.weeklyLottery.connect(this.owner).addWinRule(0.25 * 10 ** 10, 1); // There's a 25% chance 1 of us will win.
    this.weeklyLottery.connect(this.owner).addWinRule(0.05 * 10 ** 10, 2); // There's a 5% chance 2 of us will win.
    this.weeklyLottery.connect(this.owner).addWinRule(0.01 * 10 ** 10, 5); // There's a 1% chance 5 of us will win.
    this.weeklyLottery.connect(this.owner).addWinRule(0.005 * 10 ** 10, 20); // There's a 0.5% chance 20 of us will win.
    this.weeklyLottery.connect(this.owner).addWinRule(0.0001 * 10 ** 10, 2000); // There's a 0.01% chance 2000 of us will win.
  });

  it("should have correct name and symbol and decimal", async function () {
    const name = await this.lotteryToken.name();
    const symbol = await this.lotteryToken.symbol();
    const decimals = await this.lotteryToken.decimals();
    expect(name, "WeeklyLottery");
    expect(symbol, "WLT");
    expect(decimals, "18");
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

  describe("checkLotteryDecision", function () {
    beforeEach(async function () {
      this.lotteryToken = await this.LotteryToken.deploy();
      this.weeklyLottery = await this.WeeklyLottery.deploy(
        this.lotteryToken.address
      );
      this.signers.forEach((user: any) => {
        this.lotteryToken.mint(user.address, "100");
        this.lotteryToken
          .connect(user)
          .approve(this.weeklyLottery.address, "100");
        this.weeklyLottery.connect(user).buy("100");
      });

      // add Win Rule
      this.weeklyLottery.connect(this.owner).addWinRule(100 / 25, 1); // There's a 25% chance 1 of us will win.
      this.weeklyLottery.connect(this.owner).addWinRule(100 / 5, 2); // There's a 5% chance 2 of us will win.
      this.weeklyLottery.connect(this.owner).addWinRule(100 / 1, 5); // There's a 1% chance 5 of us will win.
      this.weeklyLottery.connect(this.owner).addWinRule(100 / 0.5, 20); // There's a 0.5% chance 20 of us will win.
      this.weeklyLottery.connect(this.owner).addWinRule(100 / 0.01, 2000); // There's a 0.01% chance 2000 of us will win.
    });

    it("当選者決定と分配", async function () {
      this.weeklyLottery.checkLotteryDecision();
    });
  });
});

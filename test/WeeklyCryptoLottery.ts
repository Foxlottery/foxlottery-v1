import { expect } from "chai";
import { ethers } from "hardhat";

const _link = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709";
const _coordinator = "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B";
const _keyHash =
  "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311";

const erc20TokenAmountNumber = 10 ** 20;
const erc20TokenAmount = String(erc20TokenAmountNumber);

describe("WeeklyCryptoLottery", function () {
  before(async function () {
    this.CryptoLottery = await ethers.getContractFactory("CryptoLottery");
    this.WeeklyCryptoLottery = await ethers.getContractFactory(
      "TimedRandomSendContract"
    );

    this.signers = await ethers.getSigners();
    this.owner = this.signers[0];
    this.bob = this.signers[1];
    this.carol = this.signers[2];
  });

  beforeEach(async function () {
    this.cryptoLottery = await this.CryptoLottery.deploy();
    this.weeklyCryptoLottery = await this.WeeklyCryptoLottery.deploy(
      "WeeklyCryptoLottery",
      "WLT",
      86400 * 7,
      this.cryptoLottery.address,
      _link,
      _coordinator,
      _keyHash
    );

    const randomSendingRules = [
      { raito: 1 / 0.0001, sendingCount: 2000 }, // There's a 0.01% chance 2000 of us will win. 20%
      { raito: 1 / 0.005, sendingCount: 20 }, // There's a 0.5% chance 20 of us will win. 10%
      { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win. 5%
      { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win. 10%
      { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win. 25%
    ];
    randomSendingRules.forEach(async (rule) => {
      await this.weeklyCryptoLottery.createRandomSendingRule(
        rule.raito,
        rule.sendingCount
      );
    });
    this.cryptoLottery.mint(this.owner.address, erc20TokenAmount);
    this.cryptoLottery.mint(this.bob.address, erc20TokenAmount);
    this.cryptoLottery.mint(this.carol.address, erc20TokenAmount);
  });

  it("should have correct name and symbol and decimal", async function () {
    const name = await this.cryptoLottery.name();
    const symbol = await this.cryptoLottery.symbol();
    expect(name, "WeeklyCryptoLottery");
    expect(symbol, "WLT");
  });

  it("createDefinitelySendingRule", async function () {
    await this.weeklyCryptoLottery.createDefinitelySendingRule(
      1 / 0.2,
      this.cryptoLottery.address
    );
    const ratio = await this.weeklyCryptoLottery.definitelySendingRuleRatioById(
      1
    );
    const address =
      await this.weeklyCryptoLottery.definitelySendingRuleAddressById(1);
    expect(ratio).to.equal(1 / 0.2);
    expect(address).to.equal(this.cryptoLottery.address);
  });

  it("deleteDefinitelySendingRule", async function () {
    await this.weeklyCryptoLottery.createDefinitelySendingRule(
      1 / 0.2,
      this.cryptoLottery.address
    );
    await this.weeklyCryptoLottery.deleteDefinitelySendingRule(1);
    const ratio = await this.weeklyCryptoLottery.definitelySendingRuleRatioById(
      1
    );
    const address =
      await this.weeklyCryptoLottery.definitelySendingRuleAddressById(1);
    expect(ratio).to.equal(0);
    expect(address).to.equal("0x0000000000000000000000000000000000000000");
  });

  it("lottryTokenを持っていること", async function () {
    expect(await this.cryptoLottery.balanceOf(this.owner.address)).to.equal(
      erc20TokenAmount
    );
    expect(await this.cryptoLottery.balanceOf(this.bob.address)).to.equal(
      erc20TokenAmount
    );
    expect(await this.cryptoLottery.balanceOf(this.carol.address)).to.equal(
      erc20TokenAmount
    );
  });

  it("getNumber", async function () {
    await this.cryptoLottery
      .connect(this.bob)
      .approve(this.weeklyCryptoLottery.address, erc20TokenAmount);
    await this.weeklyCryptoLottery.connect(this.bob).buy(erc20TokenAmount);

    const getNumber = await this.weeklyCryptoLottery.getNumber(1);
    console.log(`gotNumber: ${getNumber}`);
  });

  it("buy cryptoLotteryが足りないと、weeklyCryptoLottery購入ができないこと", async function () {
    await this.cryptoLottery
      .connect(this.bob)
      .approve(this.weeklyCryptoLottery.address, erc20TokenAmount);
    await this.cryptoLottery
      .connect(this.bob)
      .transfer(this.owner.address, erc20TokenAmount);
    await expect(
      this.weeklyCryptoLottery.connect(this.bob).buy(erc20TokenAmount)
    ).to.be.revertedWith("TimedRandomSendContract: Not enough erc20 tokens.");
    expect(await this.weeklyCryptoLottery.totalSupply()).to.equal("0");
    expect(await this.weeklyCryptoLottery.balanceOf(this.bob.address)).to.equal(
      "0"
    );
  });

  it("buy cryptoLotteryが minimumBuyLotteryPrice以下だと、weeklyCryptoLottery購入ができないこと", async function () {
    await this.cryptoLottery
      .connect(this.bob)
      .approve(this.weeklyCryptoLottery.address, erc20TokenAmount);
    await expect(
      this.weeklyCryptoLottery.connect(this.bob).buy("100")
    ).to.be.revertedWith(
      "TimedRandomSendContract: _amount must be set above the minimum price"
    );

    expect(await this.weeklyCryptoLottery.totalSupply()).to.equal("0");
    expect(await this.weeklyCryptoLottery.balanceOf(this.bob.address)).to.equal(
      "0"
    );
  });

  it("buy cryptoLotteryがあると、weeklyCryptoLottery購入ができること、かつcryptoLotteryが減っていること、かつ参加者に追加されていること", async function () {
    await this.cryptoLottery
      .connect(this.bob)
      .approve(this.weeklyCryptoLottery.address, erc20TokenAmount);
    await this.weeklyCryptoLottery.connect(this.bob).buy(erc20TokenAmount);

    await this.cryptoLottery
      .connect(this.owner)
      .approve(this.weeklyCryptoLottery.address, erc20TokenAmount);
    await this.weeklyCryptoLottery.connect(this.owner).buy(erc20TokenAmount);

    const totalSupply = await this.weeklyCryptoLottery.totalSupply();
    expect(totalSupply).to.equal(String(erc20TokenAmountNumber * 2));
    expect(await this.weeklyCryptoLottery.balanceOf(this.bob.address)).to.equal(
      erc20TokenAmount
    );
    expect(
      await this.weeklyCryptoLottery.balanceOf(this.owner.address)
    ).to.equal(erc20TokenAmount);
    const participantBob = await this.weeklyCryptoLottery.participants(0);
    expect(participantBob).to.equal(this.bob.address);

    const participantOwner = await this.weeklyCryptoLottery.participants(1);
    expect(participantOwner).to.equal(this.owner.address);
  });

  it("currentRandomSendingRatioTotalが70%であること", async function () {
    expect(
      (await this.weeklyCryptoLottery.currentRandomSendingRatioTotal()) /
        10 ** 18
    ).to.equal(0.7);
  });

  it("deleteRandomSendintRule RandomSendintRulesが削除できること", async function () {
    expect(
      (await this.weeklyCryptoLottery.currentRandomSendingRatioTotal()) /
        10 ** 18
    ).to.equal(0.7);
    await this.weeklyCryptoLottery.deleteRandomSendintRule(1);
    expect(
      (await this.weeklyCryptoLottery.currentRandomSendingRatioTotal()) /
        10 ** 18
    ).to.equal(0.5);
  });

  it("deleteRandomSendintRule and createRandomSendingRule 再度RandomSendintRulesを設定できること", async function () {
    expect(
      (await this.weeklyCryptoLottery.currentRandomSendingRatioTotal()) /
        10 ** 18
    ).to.equal(0.7);
    await this.weeklyCryptoLottery.deleteRandomSendintRule(1);
    expect(
      (await this.weeklyCryptoLottery.currentRandomSendingRatioTotal()) /
        10 ** 18
    ).to.equal(0.5);
    await this.weeklyCryptoLottery.createRandomSendingRule(1 / 0.0001, 2000);
    expect(
      (await this.weeklyCryptoLottery.currentRandomSendingRatioTotal()) /
        10 ** 18
    ).to.equal(0.7);
  });

  it("getDefinitelySendingRuleIds", async function () {
    await this.weeklyCryptoLottery.createDefinitelySendingRule(
      1 / 0.2,
      this.cryptoLottery.address
    );
    await this.weeklyCryptoLottery.createDefinitelySendingRule(
      1 / 0.2,
      this.cryptoLottery.address
    );
    await this.weeklyCryptoLottery.createDefinitelySendingRule(
      1 / 0.2,
      this.cryptoLottery.address
    );
    const definitelySendingRuleIds =
      await this.weeklyCryptoLottery.getDefinitelySendingRuleIds();
    expect(definitelySendingRuleIds[0]).to.equal(1);
    expect(definitelySendingRuleIds[1]).to.equal(2);
    expect(definitelySendingRuleIds[2]).to.equal(3);
  });

  describe("canChangeRuleByTime: 時間が過ぎている場合、さらにrandomSendRuleを追加できないこと", function () {
    beforeEach(async function () {
      this.cryptoLottery = await this.CryptoLottery.deploy();
      this.weeklyCryptoLottery = await this.WeeklyCryptoLottery.deploy(
        "WeeklyCryptoLottery",
        "WLT",
        10,
        this.cryptoLottery.address,
        _link,
        _coordinator,
        _keyHash
      );
      this.signers.forEach((user: any) => {
        this.cryptoLottery.mint(user.address, erc20TokenAmount);
        this.cryptoLottery
          .connect(user)
          .approve(this.weeklyCryptoLottery.address, erc20TokenAmount);
        this.weeklyCryptoLottery.connect(user).buy(erc20TokenAmount);
      });
    });

    it("エラーが出ること", async function () {
      await setTimeout(async () => {
        await expect(
          this.weeklyCryptoLottery.createRandomSendingRule(4, 1)
        ).to.be.revertedWith(
          "TimedRandomSendContract: Rule changes can be made up to one-tenth of the end time."
        );
      }, 4000);
    });
  });

  describe("canCreateDefinitelySendingRules: 100％を越してしまう場合", function () {
    beforeEach(async function () {
      this.cryptoLottery = await this.CryptoLottery.deploy();
      this.weeklyCryptoLottery = await this.WeeklyCryptoLottery.deploy(
        "WeeklyCryptoLottery",
        "WLT",
        86400 * 7,
        this.cryptoLottery.address,
        _link,
        _coordinator,
        _keyHash
      );
      this.signers.forEach((user: any) => {
        this.cryptoLottery.mint(user.address, erc20TokenAmount);
        this.cryptoLottery
          .connect(user)
          .approve(this.weeklyCryptoLottery.address, erc20TokenAmount);
        this.weeklyCryptoLottery.connect(user).buy(erc20TokenAmount);
      });

      const randomSendingRules = [
        { raito: 1 / 0.0001, sendingCount: 2000 }, // There's a 0.01% chance 2000 of us will win.
        { raito: 1 / 0.005, sendingCount: 20 }, // There's a 0.5% chance 20 of us will win.
        { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
        { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
        { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
      ];
      randomSendingRules.forEach(async (rule) => {
        await this.weeklyCryptoLottery.createRandomSendingRule(
          rule.raito,
          rule.sendingCount
        );
      });
    });

    // it("エラーが出ること Only less than 100%", async function () {
    //   await expect(
    //     this.weeklyCryptoLottery.createDefinitelySendingRule(
    //       1 / 0.5,
    //       this.cryptoLottery.address
    //     )
    //   ).to.be.revertedWith("TimedRandomSendContract: Only less than 100%");
    // });
  });
});

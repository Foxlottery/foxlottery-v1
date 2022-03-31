import { ethers } from "hardhat";

const _link = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709";
const _coordinator = "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B";
const _keyHash =
  "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311";

const erc20TokenAmountNumber = 10 ** 20;
const erc20TokenAmount = String(erc20TokenAmountNumber);

describe("TimedRandomSendContract", function () {
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
      this.cryptoLottery.address,
      _link,
      _coordinator,
      _keyHash
    );

    // set rule
    const randomSendingRules = [
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

    // buy weekly token
    this.signers.forEach((user: any) => {
      this.cryptoLottery.mint(user.address, "100");
      this.cryptoLottery
        .connect(user)
        .approve(this.weeklyCryptoLottery.address, "100");
      this.weeklyCryptoLottery.connect(user).buy("100");
    });
  });

  it("getRandomNumber", async function () {
    await this.cryptoLottery
      .connect(this.bob)
      .approve(this.weeklyCryptoLottery.address, erc20TokenAmount);
    await this.weeklyCryptoLottery.connect(this.bob).buy(erc20TokenAmount);
    const getRandomNumber = await this.weeklyCryptoLottery.getRandomNumber();
    console.log(`getRandomNumber: ${getRandomNumber}`);
  });

  it("getRandomNumberWithTotalSupply", async function () {
    await this.cryptoLottery
      .connect(this.bob)
      .approve(this.weeklyCryptoLottery.address, erc20TokenAmount);
    await this.weeklyCryptoLottery.connect(this.bob).buy(erc20TokenAmount);
    const rand = await this.weeklyCryptoLottery.getRandomNumber();
    const randWithTotalSupply =
      await this.weeklyCryptoLottery.getRandomNumberWithTotalSupply(rand);
    console.log(`randWithTotalSupply: ${randWithTotalSupply}`);
  });

  it("randSend", async function () {
    this.weeklyCryptoLottery.randSend();
  });
});

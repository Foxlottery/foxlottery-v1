import { expect } from "chai";
import { ethers } from "hardhat";

const _ticketPrice = String(10 ** 19);
const index = 1;
const sellerCommissionRatio = 100;
const cycle = 3600;
const closeTimestamp =
  Math.floor(Date.now() / 1000) +
  (3600 - (Math.floor(Date.now() / 1000) % 3600)) +
  7200;
const statuses = [
  "ACCEPTING",
  "RANDOM_VALUE_GETTING",
  "TOKEN_SENDING",
  "DONE",
  "RULE_SETTING",
];
const tokenSengingStatuses = [
  "SEND_TO_SELLER",
  "RANDOM_SEND",
  "DEFINITELY_SEND",
];
const randomValue = 10000;

async function approveAndBuyTicket(
  TestUSD: any,
  weeklyLottery: any,
  user: any,
  tokenAmount: any,
  _ticketCount: any,
  seller: any
) {
  await TestUSD.connect(user).approve(weeklyLottery.address, tokenAmount);
  await weeklyLottery.connect(user).buyTicket(_ticketCount, seller.address);
}

async function printData(
  signers: any,
  TestUSD: any,
  weeklyLottery: any,
  caller: string
) {
  console.log(caller);
  signers = await ethers.getSigners();
  const status = await weeklyLottery.status();
  console.log(`status: ${statuses[status]}`);
  await signers.forEach(async (user: any) => {
    console.log(
      `address: ${user.address}, token amount: ${await TestUSD.balanceOf(
        user.address
      )}`
    );
  });
}

async function getTicketId(weeklyLottery: any) {
  const convertRandomValueToWinnerTicketNumber =
    await weeklyLottery.convertRandomValueToWinnerTicketNumber();

  let ticketId = Math.trunc(convertRandomValueToWinnerTicketNumber / 3);
  if (convertRandomValueToWinnerTicketNumber % 3 !== 0) {
    ticketId++;
  }
  return ticketId;
}

describe("RandomValueGeneratorMock", function () {
  beforeEach(async function () {
    this.TestUSD = await ethers.getContractFactory("TestUSD");
    this.weeklyLottery = await ethers.getContractFactory("Lottery");
    this.randomValueGenerator = await ethers.getContractFactory(
      "RandomValueGeneratorMock"
    );
    this.signers = await ethers.getSigners();

    this.TestUSD = await this.TestUSD.deploy();
    // mint erc20 token to wallet address
    await this.signers.forEach(async (user: any) => {
      this.TestUSD.mint(user.address, String(10 ** 20));
    });
    this.weeklyLottery = await this.weeklyLottery.deploy(
      "weeklyLottery",
      "WLT",
      this.TestUSD.address,
      _ticketPrice,
      cycle,
      closeTimestamp
    );
    this.randomValueGenerator = await this.randomValueGenerator.deploy(
      this.weeklyLottery.address,
      randomValue
    );
    await this.weeklyLottery.setRandomValueGenerator(
      this.randomValueGenerator.address
    );
    await this.weeklyLottery.setSellerCommissionRatio(sellerCommissionRatio);

    // set rule
    const randomSendingRules = [
      { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
      { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
      { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
    ];
    await randomSendingRules.forEach(async (rule) => {
      await this.weeklyLottery.createRandomSendingRule(
        rule.raito,
        rule.sendingCount
      );
    });

    await this.weeklyLottery.createDefinitelySendingRule(
      1 / 0.1, // 10%
      this.signers[0].address // owner
    );
    await this.weeklyLottery.createDefinitelySendingRule(
      1 / 0.1, // 10%
      this.signers[1].address
    );

    await this.weeklyLottery.complatedRuleSetting();
    await this.weeklyLottery.statusToAccepting();

    await printData(
      this.signers,
      this.TestUSD,
      this.weeklyLottery,
      "beforeEach"
    );
  });

  it("send test", async function () {
    const ticketPrice = await this.weeklyLottery.ticketPrice();
    const _ticketCount = 3;
    const tokenAmount = String(ticketPrice * _ticketCount);

    const seller = this.signers[10];

    for (const user of this.signers) {
      await approveAndBuyTicket(
        this.TestUSD,
        this.weeklyLottery,
        user,
        tokenAmount,
        _ticketCount,
        seller
      );
    }

    let closeTimestamp = Number(await this.weeklyLottery.closeTimestamp());
    await ethers.provider.send("evm_mine", [closeTimestamp]);
    // finish
    await this.weeklyLottery.statusToRandomValueGetting();

    const randomValue = await this.weeklyLottery.randomValue(index);
    expect(randomValue !== 0).to.equal(true);

    const totalSupplyByIndex = await this.weeklyLottery.totalSupplyByIndex(
      index
    );
    expect(totalSupplyByIndex).to.equal("600000000000000000000");

    let status = await this.weeklyLottery.status();
    expect(statuses[status]).to.equal("TOKEN_SENDING");

    let tokenSengingStatus = await this.weeklyLottery.tokenSengingStatus();
    expect(tokenSengingStatuses[tokenSengingStatus]).to.equal("SEND_TO_SELLER");

    await this.weeklyLottery.sendToSeller();
    const sendToSellerIndex = await this.weeklyLottery.sendToSellerIndex();
    expect(sendToSellerIndex).to.equal(0);

    tokenSengingStatus = await this.weeklyLottery.tokenSengingStatus();
    expect(tokenSengingStatuses[tokenSengingStatus]).to.equal("RANDOM_SEND");

    let currentRandomSendingRuleId =
      await this.weeklyLottery.currentRandomSendingRuleId();
    expect(currentRandomSendingRuleId).to.equal(1);

    let currentRandomSendingRuleSendingCount =
      await this.weeklyLottery.currentRandomSendingRuleSendingCount();
    expect(currentRandomSendingRuleSendingCount).to.equal(1);

    await this.weeklyLottery.randomSend(await getTicketId(this.weeklyLottery));

    currentRandomSendingRuleId =
      await this.weeklyLottery.currentRandomSendingRuleId();
    expect(currentRandomSendingRuleId).to.equal(2);

    currentRandomSendingRuleSendingCount =
      await this.weeklyLottery.currentRandomSendingRuleSendingCount();
    expect(currentRandomSendingRuleSendingCount).to.equal(1);

    await this.weeklyLottery.randomSend(await getTicketId(this.weeklyLottery));

    currentRandomSendingRuleSendingCount =
      await this.weeklyLottery.currentRandomSendingRuleSendingCount();
    expect(currentRandomSendingRuleSendingCount).to.equal(2);

    await this.weeklyLottery.randomSend(await getTicketId(this.weeklyLottery));

    currentRandomSendingRuleId =
      await this.weeklyLottery.currentRandomSendingRuleId();
    expect(currentRandomSendingRuleId).to.equal(3);

    currentRandomSendingRuleSendingCount =
      await this.weeklyLottery.currentRandomSendingRuleSendingCount();
    expect(currentRandomSendingRuleSendingCount).to.equal(1);

    await this.weeklyLottery.randomSend(await getTicketId(this.weeklyLottery));

    currentRandomSendingRuleSendingCount =
      await this.weeklyLottery.currentRandomSendingRuleSendingCount();
    expect(currentRandomSendingRuleSendingCount).to.equal(2);

    await this.weeklyLottery.randomSend(await getTicketId(this.weeklyLottery));

    currentRandomSendingRuleSendingCount =
      await this.weeklyLottery.currentRandomSendingRuleSendingCount();
    expect(currentRandomSendingRuleSendingCount).to.equal(3);

    await this.weeklyLottery.randomSend(await getTicketId(this.weeklyLottery));

    currentRandomSendingRuleSendingCount =
      await this.weeklyLottery.currentRandomSendingRuleSendingCount();
    expect(currentRandomSendingRuleSendingCount).to.equal(4);

    await this.weeklyLottery.randomSend(await getTicketId(this.weeklyLottery));

    currentRandomSendingRuleSendingCount =
      await this.weeklyLottery.currentRandomSendingRuleSendingCount();
    expect(currentRandomSendingRuleSendingCount).to.equal(5);

    await this.weeklyLottery.randomSend(await getTicketId(this.weeklyLottery));
    tokenSengingStatus = await this.weeklyLottery.tokenSengingStatus();
    expect(tokenSengingStatuses[tokenSengingStatus]).to.equal(
      "DEFINITELY_SEND"
    );

    let currentDefinitelySendingId =
      await this.weeklyLottery.currentDefinitelySendingId();
    expect(currentDefinitelySendingId).to.equal(1);
    await this.weeklyLottery.definitelySend();

    currentDefinitelySendingId =
      await this.weeklyLottery.currentDefinitelySendingId();
    expect(currentDefinitelySendingId).to.equal(2);
    await this.weeklyLottery.definitelySend();

    status = await this.weeklyLottery.status();
    expect(statuses[status]).to.equal("DONE");

    const _index = await this.weeklyLottery.index();
    expect(_index).to.equal(2);

    await this.weeklyLottery.statusToAccepting();

    status = await this.weeklyLottery.status();
    expect(statuses[status]).to.equal("ACCEPTING");

    closeTimestamp = Number(await this.weeklyLottery.closeTimestamp());
    expect(closeTimestamp % 3600).to.equal(0);

    await printData(this.signers, this.TestUSD, this.weeklyLottery, "After");
  });
});

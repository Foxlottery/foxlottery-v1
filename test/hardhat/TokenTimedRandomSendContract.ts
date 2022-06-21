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
const subscriptionId = 1;
const vrfCoordinator = "0x6168499c0cFfCaCD319c818142124B7A15E857ab";
const keyHash =
  "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc";
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

async function approveAndBuyTicket(
  lotteryERC20: any,
  weeklyLottery: any,
  user: any,
  tokenAmount: any,
  _ticketCount: any,
  seller: any
) {
  await lotteryERC20.connect(user).approve(weeklyLottery.address, tokenAmount);
  await weeklyLottery.connect(user).buyTicket(_ticketCount, seller.address);
}

async function printData(
  signers: any,
  lotteryERC20: any,
  weeklyLottery: any,
  caller: string
) {
  console.log(caller);
  signers = await ethers.getSigners();
  const status = await weeklyLottery.status();
  console.log(`status: ${statuses[status]}`);
  await signers.forEach(async (user: any) => {
    console.log(
      `address: ${user.address}, token amount: ${await lotteryERC20.balanceOf(
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

describe("TokenTimedRandomSendContract", function () {
  describe("isOnlyOwner = false", function () {
    const _isOnlyOwner = false;
    describe("changing rule", function () {
      beforeEach(async function () {
        this.lotteryERC20 = await ethers.getContractFactory("LotteryERC20");
        this.weeklyLottery = await ethers.getContractFactory(
          "TokenTimedRandomSendContract"
        );
        this.signers = await ethers.getSigners();

        this.lotteryERC20 = await this.lotteryERC20.deploy();
        // mint erc20 token to wallet address
        await this.signers.forEach(async (user: any) => {
          this.lotteryERC20.mint(user.address, String(10 ** 20));
        });
        this.weeklyLottery = await this.weeklyLottery.deploy(
          "weeklyLottery",
          "WLT",
          this.lotteryERC20.address,
          _ticketPrice,
          _isOnlyOwner,
          cycle,
          closeTimestamp,
          subscriptionId,
          vrfCoordinator,
          keyHash
        );
        await this.weeklyLottery.setSellerCommissionRatio(
          sellerCommissionRatio
        );

        // set rule
        const randomSendingRules = [
          { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
          { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
          { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
        ];
        await randomSendingRules.forEach(async (rule) => {
          await this.weeklyLottery.createRandomSendingRule(
            rule.raito,
            rule.sendingCount
          );
        });

        await this.weeklyLottery.createDefinitelySendingRule(
          1 / 0.2, // 20%
          this.signers[0].address // owner
        );

        await printData(
          this.signers,
          this.lotteryERC20,
          this.weeklyLottery,
          "beforeEach"
        );
      });

      it("createRandomSendingRule should raise error", async function () {
        await this.weeklyLottery.complatedRuleSetting();
        await expect(
          this.weeklyLottery.createRandomSendingRule(1 / 0.1, 1)
        ).to.be.revertedWith("onlyByStatus");
      });

      it("createRandomSendingRule should raise error", async function () {
        await expect(
          this.weeklyLottery.createRandomSendingRule(0, 1)
        ).to.be.revertedWith("noZero");
      });

      it("createRandomSendingRule should raise error", async function () {
        await expect(
          this.weeklyLottery.createRandomSendingRule(1 / 0.1, 0)
        ).to.be.revertedWith("noZero");
      });

      it("createRandomSendingRule should raise error", async function () {
        await expect(
          this.weeklyLottery.createRandomSendingRule(1 / 0.5, 1)
        ).to.be.revertedWith("Only less than 100%");
      });

      it("createRandomSendingRule should raise error", async function () {
        await expect(
          this.weeklyLottery.createRandomSendingRule(1 / 0.0001, 1001)
        ).to.be.revertedWith("requireUnderMaxSendingCount");
      });

      it("createDefinitelySendingRule should raise error", async function () {
        await this.weeklyLottery.complatedRuleSetting();
        await expect(
          this.weeklyLottery.createDefinitelySendingRule(
            1 / 0.1, // 20%
            this.signers[1].address // owner
          )
        ).to.be.revertedWith("onlyByStatus");
      });

      it("createDefinitelySendingRule should raise error", async function () {
        await expect(
          this.weeklyLottery.createDefinitelySendingRule(
            1 / 0.2, // 20%
            this.signers[0].address // owner
          )
        ).to.be.revertedWith("This address has already been added.");
      });

      it("createDefinitelySendingRule should raise error", async function () {
        await expect(
          this.weeklyLottery.createDefinitelySendingRule(
            1 / 0.5, // 20%
            this.signers[1].address // owner
          )
        ).to.be.revertedWith("Only less than 100%");
      });

      it("createDefinitelySendingRule should raise error", async function () {
        await expect(
          this.weeklyLottery.createDefinitelySendingRule(
            0, // 20%
            this.signers[1].address // owner
          )
        ).to.be.revertedWith("noZero");
      });
    });

    describe("buyticket", function () {
      beforeEach(async function () {
        this.lotteryERC20 = await ethers.getContractFactory("LotteryERC20");
        this.weeklyLottery = await ethers.getContractFactory(
          "TokenTimedRandomSendContract"
        );
        this.signers = await ethers.getSigners();

        this.lotteryERC20 = await this.lotteryERC20.deploy();
        // mint erc20 token to wallet address
        await this.signers.forEach(async (user: any) => {
          this.lotteryERC20.mint(user.address, String(10 ** 20));
        });
        this.weeklyLottery = await this.weeklyLottery.deploy(
          "weeklyLottery",
          "WLT",
          this.lotteryERC20.address,
          _ticketPrice,
          _isOnlyOwner,
          cycle,
          closeTimestamp,
          subscriptionId,
          vrfCoordinator,
          keyHash
        );
        await this.weeklyLottery.setSellerCommissionRatio(
          sellerCommissionRatio
        );

        // set rule
        const randomSendingRules = [
          { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
          { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
          { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
        ];
        await randomSendingRules.forEach(async (rule) => {
          await this.weeklyLottery.createRandomSendingRule(
            rule.raito,
            rule.sendingCount
          );
        });

        await this.weeklyLottery.createDefinitelySendingRule(
          1 / 0.2, // 20%
          this.signers[0].address // owner
        );

        await this.weeklyLottery.complatedRuleSetting();
        await this.weeklyLottery.statusToAccepting();

        await printData(
          this.signers,
          this.lotteryERC20,
          this.weeklyLottery,
          "beforeEach"
        );
      });

      it("should have correct init value", async function () {
        const erc20 = await this.weeklyLottery.erc20();
        const name = await this.weeklyLottery.name();
        const symbol = await this.weeklyLottery.symbol();
        const ticketPrice = await this.weeklyLottery.ticketPrice();
        const ticketLastId = await this.weeklyLottery.ticketLastId(index);
        const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
          index,
          ticketLastId.toString()
        );
        const ticketCount = await this.weeklyLottery.ticketCount(
          index,
          ticketLastId.toString()
        );
        const isParticipated = await this.weeklyLottery.isParticipated(
          index,
          this.signers[0].address
        );
        const participantCount = await this.weeklyLottery.participantCount(
          index
        );
        const isOnlyOwner = await this.weeklyLottery.isOnlyOwner();

        expect(name).to.equal("weeklyLottery");
        expect(symbol).to.equal("WLT");
        expect(ticketPrice).to.equal(_ticketPrice);
        expect(this.lotteryERC20.address).to.equal(erc20);
        expect(ticketLastId).to.equal("0");
        expect(ticketLastNumber).to.equal("0");
        expect(ticketCount).to.equal("0");
        expect(isParticipated).to.equal(false);
        expect(participantCount).to.equal("0");
        expect(isOnlyOwner).to.equal(false);
      });

      it("Owner should buy ticket", async function () {
        const user = this.signers[0];
        const ticketPrice = await this.weeklyLottery.ticketPrice();
        const _ticketCount = 3;
        const tokenAmount = String(ticketPrice * _ticketCount);

        const seller = this.signers[10];
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          user,
          tokenAmount,
          _ticketCount,
          seller
        );

        // ticketLastIdが追加されていること
        const ticketLastId = await this.weeklyLottery.ticketLastId(index);
        expect(ticketLastId).to.equal("1");

        // ticketLastNumberがあること
        const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
          index,
          ticketLastId.toString()
        );
        expect(ticketLastNumber).to.equal("3");

        // ticketCountが追加されていること
        const ticketCount = await this.weeklyLottery.ticketCount(
          index,
          ticketLastId.toString()
        );
        expect(ticketCount).to.equal("3");

        // isParticipatedがtrueに更新されていること
        const isParticipated = await this.weeklyLottery.isParticipated(
          index,
          user.address
        );
        expect(isParticipated).to.equal(true);

        // participantCountが更新されていること
        const participantCount = await this.weeklyLottery.participantCount(
          index
        );
        expect(participantCount).to.equal("1");

        // ticketIds
        const ticketIds = await this.weeklyLottery.ticketIds(
          index,
          user.address
        );
        expect(ticketIds[0]).to.equal("1");

        // ticketReceivedAt
        const ticketReceivedAt = await this.weeklyLottery.ticketReceivedAt(
          index,
          ticketLastId
        );
        expect(ticketReceivedAt <= new Date().getTime()).to.equal(true);

        // 送金ができていること
        const buyerAmount = await this.lotteryERC20.balanceOf(user.address);
        expect(buyerAmount).to.equal("70000000000000000000");

        // sellerの登録されていること
        const sellers = await this.weeklyLottery.sellers(index);
        expect(sellers[0]).to.equal(seller.address);
        let isSeller = await this.weeklyLottery.isSeller(index, seller.address);
        expect(isSeller).to.equal(true);
        isSeller = await this.weeklyLottery.isSeller(index, user.address);
        expect(isSeller).to.equal(false);
        let tokenAmountToSeller = await this.weeklyLottery.tokenAmountToSeller(
          index,
          seller.address
        );
        expect(tokenAmountToSeller).to.equal("300000000000000000");
        tokenAmountToSeller = await this.weeklyLottery.tokenAmountToSeller(
          index,
          user.address
        );
        expect(tokenAmountToSeller).to.equal(0);

        // totalSupply
        const totalSupply = await this.weeklyLottery.totalSupply();
        expect(totalSupply).to.equal("30000000000000000000");

        await printData(
          this.signers,
          this.lotteryERC20,
          this.weeklyLottery,
          "After"
        );
      });

      it("Two user should buy ticket", async function () {
        const ticketPrice = await this.weeklyLottery.ticketPrice();
        const _ticketCount = 3;
        const tokenAmount = String(ticketPrice * _ticketCount);

        const user = this.signers[1];
        const seller = this.signers[10];
        // first
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          this.signers[0],
          tokenAmount,
          _ticketCount,
          seller
        );
        // second
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          this.signers[1],
          tokenAmount,
          _ticketCount,
          seller
        );

        // ticketLastIdが追加されていること
        const ticketLastId = await this.weeklyLottery.ticketLastId(index);
        expect(ticketLastId).to.equal("2");

        // ticketLastNumberがあること
        const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
          index,
          ticketLastId.toString()
        );
        expect(ticketLastNumber).to.equal("6");

        // ticketCountが追加されていること
        const ticketCount = await this.weeklyLottery.ticketCount(
          index,
          ticketLastId.toString()
        );
        expect(ticketCount).to.equal("3");

        // isParticipatedがtrueに更新されていること
        const isParticipated = await this.weeklyLottery.isParticipated(
          index,
          user.address
        );
        expect(isParticipated).to.equal(true);

        // participantCountが更新されていること
        const participantCount = await this.weeklyLottery.participantCount(
          index
        );
        expect(participantCount).to.equal("2");

        // ticketIds
        const ticketIds = await this.weeklyLottery.ticketIds(
          index,
          user.address
        );
        expect(ticketIds[0]).to.equal("2");

        // ticketReceivedAt
        const ticketReceivedAt = await this.weeklyLottery.ticketReceivedAt(
          index,
          ticketLastId
        );
        expect(ticketReceivedAt <= new Date().getTime()).to.equal(true);

        // 送金ができていること
        let buyerAmount = await this.lotteryERC20.balanceOf(user.address);
        expect(buyerAmount).to.equal("70000000000000000000");

        buyerAmount = await this.lotteryERC20.balanceOf(
          this.signers[1].address
        );
        expect(buyerAmount).to.equal("70000000000000000000");

        // sellerの登録されていること
        const sellers = await this.weeklyLottery.sellers(index);
        expect(sellers[0]).to.equal(seller.address);
        let isSeller = await this.weeklyLottery.isSeller(index, seller.address);
        expect(isSeller).to.equal(true);
        isSeller = await this.weeklyLottery.isSeller(index, user.address);
        expect(isSeller).to.equal(false);
        let tokenAmountToSeller = await this.weeklyLottery.tokenAmountToSeller(
          index,
          seller.address
        );
        expect(tokenAmountToSeller).to.equal("600000000000000000");
        tokenAmountToSeller = await this.weeklyLottery.tokenAmountToSeller(
          index,
          user.address
        );
        expect(tokenAmountToSeller).to.equal(0);

        const totalSupply = await this.weeklyLottery.totalSupply();
        expect(totalSupply).to.equal("60000000000000000000");

        await printData(
          this.signers,
          this.lotteryERC20,
          this.weeklyLottery,
          "After"
        );
      });

      it("Three user should buy ticket", async function () {
        const ticketPrice = await this.weeklyLottery.ticketPrice();
        const _ticketCount = 3;
        const tokenAmount = String(ticketPrice * _ticketCount);

        const user = this.signers[2];
        const seller = this.signers[10];
        // first
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          this.signers[0],
          tokenAmount,
          _ticketCount,
          seller
        );
        // second
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          this.signers[1],
          tokenAmount,
          _ticketCount,
          seller
        );
        // third
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          this.signers[2],
          tokenAmount,
          _ticketCount,
          seller
        );

        // ticketLastIdが追加されていること
        const ticketLastId = await this.weeklyLottery.ticketLastId(index);
        expect(ticketLastId).to.equal("3");

        // ticketLastNumberがあること
        const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
          index,
          ticketLastId.toString()
        );
        expect(ticketLastNumber).to.equal("9");

        // ticketCountが追加されていること
        const ticketCount = await this.weeklyLottery.ticketCount(
          index,
          ticketLastId.toString()
        );
        expect(ticketCount).to.equal("3");

        // isParticipatedがtrueに更新されていること
        const isParticipated = await this.weeklyLottery.isParticipated(
          index,
          user.address
        );
        expect(isParticipated).to.equal(true);

        // participantCountが更新されていること
        const participantCount = await this.weeklyLottery.participantCount(
          index
        );
        expect(participantCount).to.equal("3");

        // ticketIds
        const ticketIds = await this.weeklyLottery.ticketIds(
          index,
          user.address
        );
        expect(ticketIds[0]).to.equal("3");

        // ticketReceivedAt
        const ticketReceivedAt = await this.weeklyLottery.ticketReceivedAt(
          index,
          ticketLastId
        );
        expect(ticketReceivedAt <= new Date().getTime()).to.equal(true);

        // 送金ができていること
        let buyerAmount = await this.lotteryERC20.balanceOf(
          this.signers[2].address
        );
        expect(buyerAmount).to.equal("70000000000000000000");

        buyerAmount = await this.lotteryERC20.balanceOf(
          this.signers[1].address
        );
        expect(buyerAmount).to.equal("70000000000000000000");

        buyerAmount = await this.lotteryERC20.balanceOf(
          this.signers[0].address
        );
        expect(buyerAmount).to.equal("70000000000000000000");

        // sellerの登録されていること
        const sellers = await this.weeklyLottery.sellers(index);
        expect(sellers[0]).to.equal(seller.address);
        let isSeller = await this.weeklyLottery.isSeller(index, seller.address);
        expect(isSeller).to.equal(true);
        isSeller = await this.weeklyLottery.isSeller(index, user.address);
        expect(isSeller).to.equal(false);
        let tokenAmountToSeller = await this.weeklyLottery.tokenAmountToSeller(
          index,
          seller.address
        );
        expect(tokenAmountToSeller).to.equal("900000000000000000");
        tokenAmountToSeller = await this.weeklyLottery.tokenAmountToSeller(
          index,
          user.address
        );
        expect(tokenAmountToSeller).to.equal(0);

        const totalSupply = await this.weeklyLottery.totalSupply();
        expect(totalSupply).to.equal("90000000000000000000");

        await printData(
          this.signers,
          this.lotteryERC20,
          this.weeklyLottery,
          "After"
        );
      });

      it("The same user buys ticket again.", async function () {
        const ticketPrice = await this.weeklyLottery.ticketPrice();
        const _ticketCount = 3;
        const tokenAmount = String(ticketPrice * _ticketCount);

        const user = this.signers[0];
        // first
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          this.signers[0],
          tokenAmount,
          _ticketCount,
          this.signers[10]
        );
        // second
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          this.signers[1],
          tokenAmount,
          _ticketCount,
          this.signers[10]
        );
        // third
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          this.signers[2],
          tokenAmount,
          _ticketCount,
          this.signers[10]
        );
        // The same user buys ticket again.
        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          this.signers[0], // same user
          tokenAmount,
          _ticketCount,
          this.signers[10]
        );

        // ticketLastIdが追加されていること
        const ticketLastId = await this.weeklyLottery.ticketLastId(index);
        expect(ticketLastId).to.equal("4");

        // ticketLastNumberがあること
        const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
          index,
          ticketLastId.toString()
        );
        expect(ticketLastNumber).to.equal("12");

        // ticketCountが追加されていること
        const ticketCount = await this.weeklyLottery.ticketCount(
          index,
          ticketLastId.toString()
        );
        expect(ticketCount).to.equal("3");

        // isParticipatedがtrueに更新されていること
        const isParticipated = await this.weeklyLottery.isParticipated(
          index,
          user.address
        );
        expect(isParticipated).to.equal(true);

        // participantCountが更新されていること
        const participantCount = await this.weeklyLottery.participantCount(
          index
        );
        expect(participantCount).to.equal("3");

        // ticketIds
        let ticketIds = await this.weeklyLottery.ticketIds(
          index,
          this.signers[0].address
        );
        expect(ticketIds[0]).to.equal("1");
        expect(ticketIds[1]).to.equal("4");

        ticketIds = await this.weeklyLottery.ticketIds(
          index,
          this.signers[1].address
        );
        expect(ticketIds[0]).to.equal("2");

        ticketIds = await this.weeklyLottery.ticketIds(
          index,
          this.signers[2].address
        );
        expect(ticketIds[0]).to.equal("3");

        // ticketReceivedAt
        const ticketReceivedAt = await this.weeklyLottery.ticketReceivedAt(
          index,
          ticketLastId
        );
        expect(ticketReceivedAt <= new Date().getTime()).to.equal(true);

        // 送金ができていること
        let buyerAmount = await this.lotteryERC20.balanceOf(
          this.signers[2].address
        );
        expect(buyerAmount).to.equal("70000000000000000000");

        buyerAmount = await this.lotteryERC20.balanceOf(
          this.signers[1].address
        );
        expect(buyerAmount).to.equal("70000000000000000000");

        buyerAmount = await this.lotteryERC20.balanceOf(
          this.signers[0].address
        );
        expect(buyerAmount).to.equal("40000000000000000000");

        // sellerがtokenをもらっていること
        const sellerAmount = await this.lotteryERC20.balanceOf(
          this.signers[10].address
        );
        expect(sellerAmount).to.equal("100000000000000000000");

        const totalSupply = await this.weeklyLottery.totalSupply();
        expect(totalSupply).to.equal("120000000000000000000");
      });

      it("Owner should send ticket", async function () {
        const user = this.signers[0];
        const ticketPrice = await this.weeklyLottery.ticketPrice();
        const _ticketCount = 3;
        const tokenAmount = String(ticketPrice * _ticketCount);

        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          user,
          tokenAmount,
          _ticketCount,
          this.signers[10]
        );

        await this.weeklyLottery.sendTicket(0, this.signers[1].address);
        // ticketIds
        let ticketIds = await this.weeklyLottery.ticketIds(
          index,
          this.signers[0].address
        );
        expect(ticketIds.length).to.equal(0);

        ticketIds = await this.weeklyLottery.ticketIds(
          index,
          this.signers[1].address
        );
        expect(ticketIds[0]).to.equal("1");
        expect(ticketIds.length).to.equal(1);

        const ticketLastId = await this.weeklyLottery.ticketLastId(index);
        expect(ticketLastId).to.equal("1");

        // ticketLastNumberがあること
        const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
          index,
          ticketLastId.toString()
        );
        expect(ticketLastNumber).to.equal("3");

        // ticketCountが追加されていること
        const ticketCount = await this.weeklyLottery.ticketCount(
          index,
          ticketLastId.toString()
        );
        expect(ticketCount).to.equal("3");

        // isParticipatedがtrueに更新されていること
        const isParticipated = await this.weeklyLottery.isParticipated(
          index,
          this.signers[1].address
        );
        expect(isParticipated).to.equal(true);

        // participantCountが更新されていること
        const participantCount = await this.weeklyLottery.participantCount(
          index
        );
        expect(participantCount).to.equal("2");

        const totalSupply = await this.weeklyLottery.totalSupply();
        expect(totalSupply).to.equal("30000000000000000000");
      });

      it("Non-Owner can not send ticket", async function () {
        const user = this.signers[1];
        const ticketPrice = await this.weeklyLottery.ticketPrice();
        const _ticketCount = 3;
        const tokenAmount = String(ticketPrice * _ticketCount);

        await approveAndBuyTicket(
          this.lotteryERC20,
          this.weeklyLottery,
          user,
          tokenAmount,
          _ticketCount,
          this.signers[10]
        );

        await expect(
          this.weeklyLottery
            .connect(user)
            .sendTicket(0, this.signers[2].address)
        ).to.be.revertedWith("Ownable: caller is not the owner");

        const totalSupply = await this.weeklyLottery.totalSupply();
        expect(totalSupply).to.equal("30000000000000000000");
      });
    });
  });

  describe("send ticket & buy ticket when isOnlyOwner = true", function () {
    const _isOnlyOwner = true;

    beforeEach(async function () {
      this.lotteryERC20 = await ethers.getContractFactory("LotteryERC20");
      this.weeklyLottery = await ethers.getContractFactory(
        "TokenTimedRandomSendContract"
      );
      this.signers = await ethers.getSigners();

      this.lotteryERC20 = await this.lotteryERC20.deploy();
      // mint erc20 token to wallet address
      await this.signers.forEach(async (user: any) => {
        this.lotteryERC20.mint(user.address, String(10 ** 20));
      });

      this.weeklyLottery = await this.weeklyLottery.deploy(
        "weeklyLottery",
        "WLT",
        this.lotteryERC20.address,
        _ticketPrice,
        _isOnlyOwner,
        cycle,
        closeTimestamp,
        subscriptionId,
        vrfCoordinator,
        keyHash
      );

      await this.weeklyLottery.setSellerCommissionRatio(sellerCommissionRatio);
      // set rule
      const randomSendingRules = [
        { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
        { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
        { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
      ];
      randomSendingRules.forEach(async (rule) => {
        await this.weeklyLottery.createRandomSendingRule(
          rule.raito,
          rule.sendingCount
        );
      });

      await this.weeklyLottery.createDefinitelySendingRule(
        1 / 0.2, // 20%
        this.signers[0].address // owner
      );

      await this.weeklyLottery.complatedRuleSetting();
      await this.weeklyLottery.statusToAccepting();

      await printData(
        this.signers,
        this.lotteryERC20,
        this.weeklyLottery,
        "beforeEach"
      );
    });

    it("should have correct init value", async function () {
      const erc20 = await this.weeklyLottery.erc20();
      const name = await this.weeklyLottery.name();
      const symbol = await this.weeklyLottery.symbol();
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const ticketLastId = await this.weeklyLottery.ticketLastId(index);
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        index,
        ticketLastId.toString()
      );
      const ticketCount = await this.weeklyLottery.ticketCount(
        index,
        ticketLastId.toString()
      );
      const isParticipated = await this.weeklyLottery.isParticipated(
        index,
        this.signers[0].address
      );
      const participantCount = await this.weeklyLottery.participantCount(index);
      const isOnlyOwner = await this.weeklyLottery.isOnlyOwner();

      expect(name).to.equal("weeklyLottery");
      expect(symbol).to.equal("WLT");
      expect(ticketPrice).to.equal(_ticketPrice);
      expect(this.lotteryERC20.address).to.equal(erc20);
      expect(ticketLastId).to.equal("0");
      expect(ticketLastNumber).to.equal("0");
      expect(ticketCount).to.equal("0");
      expect(isParticipated).to.equal(false);
      expect(participantCount).to.equal("0");
      expect(isOnlyOwner).to.equal(true);
    });

    it("Owner user can buy ticket", async function () {
      const user = this.signers[0];
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      await approveAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        user,
        tokenAmount,
        _ticketCount,
        this.signers[10]
      );

      // ticketLastIdが追加されていること
      const ticketLastId = await this.weeklyLottery.ticketLastId(index);
      expect(ticketLastId).to.equal("1");

      // ticketLastNumberがあること
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        index,
        ticketLastId.toString()
      );
      expect(ticketLastNumber).to.equal("3");

      // ticketCountが追加されていること
      const ticketCount = await this.weeklyLottery.ticketCount(
        index,
        ticketLastId.toString()
      );
      expect(ticketCount).to.equal("3");

      // isParticipatedがtrueに更新されていること
      const isParticipated = await this.weeklyLottery.isParticipated(
        index,
        user.address
      );
      expect(isParticipated).to.equal(true);

      // participantCountが更新されていること
      const participantCount = await this.weeklyLottery.participantCount(index);
      expect(participantCount).to.equal("1");

      // ticketIds
      const ticketIds = await this.weeklyLottery.ticketIds(index, user.address);
      expect(ticketIds[0]).to.equal("1");

      // ticketReceivedAt
      const ticketReceivedAt = await this.weeklyLottery.ticketReceivedAt(
        index,
        ticketLastId
      );
      expect(ticketReceivedAt <= new Date().getTime()).to.equal(true);
    });

    it("Non-Owner can not buy ticket", async function () {
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      const user = this.signers[1];
      // first
      await approveAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[0],
        tokenAmount,
        _ticketCount,
        this.signers[10]
      );
      // second
      await this.lotteryERC20
        .connect(user)
        .approve(this.weeklyLottery.address, tokenAmount);
      await expect(
        this.weeklyLottery
          .connect(user)
          .buyTicket(_ticketCount, this.signers[10].address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      // ticketLastIdが追加されてないこと
      const ticketLastId = await this.weeklyLottery.ticketLastId(index);
      expect(ticketLastId).to.equal("1");

      // ticketLastNumberが追加されてないこと
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        index,
        ticketLastId.toString()
      );
      expect(ticketLastNumber).to.equal("3");

      const ticketCount = await this.weeklyLottery.ticketCount(index, "2");
      expect(ticketCount).to.equal("0");

      const isParticipated = await this.weeklyLottery.isParticipated(
        index,
        user.address
      );
      expect(isParticipated).to.equal(false);

      // participantCountが更新されていること
      const participantCount = await this.weeklyLottery.participantCount(index);
      expect(participantCount).to.equal("1");

      // ticketIds
      const ticketIds = await this.weeklyLottery.ticketIds(index, user.address);
      expect(ticketIds.length).to.equal(0);
    });
  });

  // describe("token sending test", async function () {
  //   const _isOnlyOwner = false;
  //   beforeEach(async function () {
  //     this.lotteryERC20 = await ethers.getContractFactory("LotteryERC20");
  //     this.weeklyLottery = await ethers.getContractFactory(
  //       "TokenTimedRandomSendContract"
  //     );
  //     this.signers = await ethers.getSigners();

  //     this.lotteryERC20 = await this.lotteryERC20.deploy();
  //     // mint erc20 token to wallet address
  //     await this.signers.forEach(async (user: any) => {
  //       this.lotteryERC20.mint(user.address, String(10 ** 20));
  //     });
  //     this.weeklyLottery = await this.weeklyLottery.deploy(
  //       "weeklyLottery",
  //       "WLT",
  //       this.lotteryERC20.address,
  //       _ticketPrice,
  //       _isOnlyOwner,
  //       cycle,
  //       closeTimestamp,
  //       subscriptionId,
  //       vrfCoordinator,
  //       keyHash
  //     );
  //     await this.weeklyLottery.setSellerCommissionRatio(sellerCommissionRatio);

  //     // set rule
  //     const randomSendingRules = [
  //       { raito: 1 / 0.01, sendingCount: 5 }, // There's a 1% chance 5 of us will win.
  //       { raito: 1 / 0.05, sendingCount: 2 }, // There's a 5% chance 2 of us will win.
  //       { raito: 1 / 0.25, sendingCount: 1 }, // There's a 25% chance 1 of us will win.
  //     ];
  //     await randomSendingRules.forEach(async (rule) => {
  //       await this.weeklyLottery.createRandomSendingRule(
  //         rule.raito,
  //         rule.sendingCount
  //       );
  //     });

  //     await this.weeklyLottery.createDefinitelySendingRule(
  //       1 / 0.1, // 10%
  //       this.signers[0].address // owner
  //     );
  //     await this.weeklyLottery.createDefinitelySendingRule(
  //       1 / 0.1, // 10%
  //       this.signers[1].address
  //     );

  //     await this.weeklyLottery.complatedRuleSetting();
  //     await this.weeklyLottery.statusToAccepting();

  //     await printData(
  //       this.signers,
  //       this.lotteryERC20,
  //       this.weeklyLottery,
  //       "beforeEach"
  //     );
  //   });

  //   it("send test", async function () {
  //     const ticketPrice = await this.weeklyLottery.ticketPrice();
  //     const _ticketCount = 3;
  //     const tokenAmount = String(ticketPrice * _ticketCount);

  //     const seller = this.signers[10];

  //     for (const user of this.signers) {
  //       await approveAndBuyTicket(
  //         this.lotteryERC20,
  //         this.weeklyLottery,
  //         user,
  //         tokenAmount,
  //         _ticketCount,
  //         seller
  //       );
  //     }

  //     let closeTimestamp = Number(await this.weeklyLottery.closeTimestamp());
  //     await ethers.provider.send("evm_mine", [closeTimestamp]);
  //     // finish
  //     await this.weeklyLottery.statusToRandomValueGetting();

  //     const randomValue = await this.weeklyLottery.randomValue(index);
  //     expect(randomValue !== 0).to.equal(true);

  //     const totalSupplyByIndex = await this.weeklyLottery.totalSupplyByIndex(
  //       index
  //     );
  //     expect(totalSupplyByIndex).to.equal("600000000000000000000");

  //     let status = await this.weeklyLottery.status();
  //     expect(statuses[status]).to.equal("TOKEN_SENDING");

  //     let tokenSengingStatus = await this.weeklyLottery.tokenSengingStatus();
  //     expect(tokenSengingStatuses[tokenSengingStatus]).to.equal(
  //       "SEND_TO_SELLER"
  //     );

  //     await this.weeklyLottery.sendToSeller();
  //     const sendToSellerIndex = await this.weeklyLottery.sendToSellerIndex();
  //     expect(sendToSellerIndex).to.equal(0);

  //     tokenSengingStatus = await this.weeklyLottery.tokenSengingStatus();
  //     expect(tokenSengingStatuses[tokenSengingStatus]).to.equal("RANDOM_SEND");

  //     let currentRandomSendingRuleSendingCount =
  //       await this.weeklyLottery.currentRandomSendingRuleSendingCount();
  //     expect(currentRandomSendingRuleSendingCount).to.equal(1);

  //     await this.weeklyLottery.randomSend(
  //       await getTicketId(this.weeklyLottery)
  //     );

  //     currentRandomSendingRuleSendingCount =
  //       await this.weeklyLottery.currentRandomSendingRuleSendingCount();
  //     expect(currentRandomSendingRuleSendingCount).to.equal(2);

  //     await this.weeklyLottery.randomSend(
  //       await getTicketId(this.weeklyLottery)
  //     );

  //     currentRandomSendingRuleSendingCount =
  //       await this.weeklyLottery.currentRandomSendingRuleSendingCount();
  //     expect(currentRandomSendingRuleSendingCount).to.equal(3);

  //     await this.weeklyLottery.randomSend(
  //       await getTicketId(this.weeklyLottery)
  //     );
  //     currentRandomSendingRuleSendingCount =
  //       await this.weeklyLottery.currentRandomSendingRuleSendingCount();
  //     expect(currentRandomSendingRuleSendingCount).to.equal(4);

  //     await this.weeklyLottery.randomSend(
  //       await getTicketId(this.weeklyLottery)
  //     );

  //     currentRandomSendingRuleSendingCount =
  //       await this.weeklyLottery.currentRandomSendingRuleSendingCount();
  //     expect(currentRandomSendingRuleSendingCount).to.equal(5);

  //     await this.weeklyLottery.randomSend(
  //       await getTicketId(this.weeklyLottery)
  //     );

  //     let currentRandomSendingRuleId =
  //       await this.weeklyLottery.currentRandomSendingRuleId();
  //     expect(currentRandomSendingRuleId).to.equal(2);

  //     currentRandomSendingRuleSendingCount =
  //       await this.weeklyLottery.currentRandomSendingRuleSendingCount();
  //     expect(currentRandomSendingRuleSendingCount).to.equal(1);

  //     await this.weeklyLottery.randomSend(
  //       await getTicketId(this.weeklyLottery)
  //     );

  //     currentRandomSendingRuleSendingCount =
  //       await this.weeklyLottery.currentRandomSendingRuleSendingCount();
  //     expect(currentRandomSendingRuleSendingCount).to.equal(2);

  //     await this.weeklyLottery.randomSend(
  //       await getTicketId(this.weeklyLottery)
  //     );
  //     currentRandomSendingRuleId =
  //       await this.weeklyLottery.currentRandomSendingRuleId();
  //     expect(currentRandomSendingRuleId).to.equal(3);

  //     currentRandomSendingRuleSendingCount =
  //       await this.weeklyLottery.currentRandomSendingRuleSendingCount();
  //     expect(currentRandomSendingRuleSendingCount).to.equal(1);

  //     await this.weeklyLottery.randomSend(
  //       await getTicketId(this.weeklyLottery)
  //     );
  //     tokenSengingStatus = await this.weeklyLottery.tokenSengingStatus();
  //     expect(tokenSengingStatuses[tokenSengingStatus]).to.equal(
  //       "DEFINITELY_SEND"
  //     );

  //     let currentDefinitelySendingId =
  //       await this.weeklyLottery.currentDefinitelySendingId();
  //     expect(currentDefinitelySendingId).to.equal(1);
  //     await this.weeklyLottery.definitelySend();

  //     currentDefinitelySendingId =
  //       await this.weeklyLottery.currentDefinitelySendingId();
  //     expect(currentDefinitelySendingId).to.equal(2);
  //     await this.weeklyLottery.definitelySend();

  //     status = await this.weeklyLottery.status();
  //     expect(statuses[status]).to.equal("DONE");

  //     const _index = await this.weeklyLottery.index();
  //     expect(_index).to.equal(2);

  //     await this.weeklyLottery.statusToAccepting();

  //     status = await this.weeklyLottery.status();
  //     expect(statuses[status]).to.equal("ACCEPTING");

  //     closeTimestamp = Number(await this.weeklyLottery.closeTimestamp());
  //     expect(closeTimestamp % 3600).to.equal(0);

  //     await printData(
  //       this.signers,
  //       this.lotteryERC20,
  //       this.weeklyLottery,
  //       "After"
  //     );
  //   });
  // });
});

import { expect } from "chai";
import { ethers } from "hardhat";

const _link = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709";
const _coordinator = "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B";
const _keyHash =
  "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311";
const _ticketPrice = String(10 ** 19);
const _cycleTimestamp = 120;
const index = 1;
const sellerCommission = 100;

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
  await signers.forEach(async (user: any) => {
    console.log(
      `address: ${user.address}, token amount: ${await lotteryERC20.balanceOf(
        user.address
      )}`
    );
  });
}

describe("TokenTimedRandomSendContract", function () {
  describe("when isOnlyOwner = false", function () {
    const _isOnlyOwner = false;

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
        _cycleTimestamp,
        this.lotteryERC20.address,
        _link,
        _coordinator,
        _keyHash,
        sellerCommission,
        _ticketPrice,
        _isOnlyOwner
      );
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
      const cycleTimestamp = await this.weeklyLottery.cycleTimestamp();
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
      const keyHash = await this.weeklyLottery.keyHash();
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
      expect(cycleTimestamp).to.equal(_cycleTimestamp.toString());
      expect(this.lotteryERC20.address).to.equal(erc20);
      expect(keyHash).to.equal(_keyHash);
      expect(ticketLastId).to.equal("0");
      expect(ticketLastNumber).to.equal("0");
      expect(ticketCount).to.equal("0");
      expect(isParticipated).to.equal(false);
      expect(participantCount).to.equal("0");
      expect(isOnlyOwner).to.equal(false);
    });

    it("Owner should buy ticket", async function () {
      const user = this.signers[0];
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
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

      // 送金ができていること
      const buyerAmount = await this.lotteryERC20.balanceOf(user.address);
      expect(buyerAmount).to.equal("70000000000000000000");

      // sellerがtokenをもらっていること
      const sellerAmount = await this.lotteryERC20.balanceOf(
        this.signers[10].address
      );
      expect(sellerAmount).to.equal("100300000000000000000");

      const totalSupply = await this.weeklyLottery.totalSupply();
      expect(totalSupply).to.equal("29700000000000000000");

      await printData(
        this.signers,
        this.lotteryERC20,
        this.weeklyLottery,
        "After"
      );
    });

    it("Two user should buy ticket", async function () {
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
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
      await approveAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[1],
        tokenAmount,
        _ticketCount,
        this.signers[10]
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
      const participantCount = await this.weeklyLottery.participantCount(index);
      expect(participantCount).to.equal("2");

      // ticketIds
      const ticketIds = await this.weeklyLottery.ticketIds(index, user.address);
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

      buyerAmount = await this.lotteryERC20.balanceOf(this.signers[1].address);
      expect(buyerAmount).to.equal("70000000000000000000");

      // sellerがtokenをもらっていること
      const sellerAmount = await this.lotteryERC20.balanceOf(
        this.signers[10].address
      );
      expect(sellerAmount).to.equal("100600000000000000000");

      const totalSupply = await this.weeklyLottery.totalSupply();
      expect(totalSupply).to.equal("59400000000000000000");

      await printData(
        this.signers,
        this.lotteryERC20,
        this.weeklyLottery,
        "After"
      );
    });

    it("Three user should buy ticket", async function () {
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      const user = this.signers[2];
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
      const participantCount = await this.weeklyLottery.participantCount(index);
      expect(participantCount).to.equal("3");

      // ticketIds
      const ticketIds = await this.weeklyLottery.ticketIds(index, user.address);
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

      buyerAmount = await this.lotteryERC20.balanceOf(this.signers[1].address);
      expect(buyerAmount).to.equal("70000000000000000000");

      buyerAmount = await this.lotteryERC20.balanceOf(this.signers[0].address);
      expect(buyerAmount).to.equal("70000000000000000000");

      // sellerがtokenをもらっていること
      const sellerAmount = await this.lotteryERC20.balanceOf(
        this.signers[10].address
      );
      expect(sellerAmount).to.equal("100900000000000000000");

      const totalSupply = await this.weeklyLottery.totalSupply();
      expect(totalSupply).to.equal("89100000000000000000");

      await printData(
        this.signers,
        this.lotteryERC20,
        this.weeklyLottery,
        "After"
      );
    });

    it("The same user buys ticket again.", async function () {
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
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
      const participantCount = await this.weeklyLottery.participantCount(index);
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

      buyerAmount = await this.lotteryERC20.balanceOf(this.signers[1].address);
      expect(buyerAmount).to.equal("70000000000000000000");

      buyerAmount = await this.lotteryERC20.balanceOf(this.signers[0].address);
      expect(buyerAmount).to.equal("40000000000000000000");

      // sellerがtokenをもらっていること
      const sellerAmount = await this.lotteryERC20.balanceOf(
        this.signers[10].address
      );
      expect(sellerAmount).to.equal("101200000000000000000");

      const totalSupply = await this.weeklyLottery.totalSupply();
      expect(totalSupply).to.equal("118800000000000000000");
    });

    it("Owner should send ticket", async function () {
      const user = this.signers[0];
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
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
      const participantCount = await this.weeklyLottery.participantCount(index);
      expect(participantCount).to.equal("2");

      const totalSupply = await this.weeklyLottery.totalSupply();
      expect(totalSupply).to.equal("29700000000000000000");
    });

    it("Non-Owner can not send ticket", async function () {
      const user = this.signers[1];
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
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
        this.weeklyLottery.connect(user).sendTicket(0, this.signers[2].address)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      const totalSupply = await this.weeklyLottery.totalSupply();
      expect(totalSupply).to.equal("29700000000000000000");
    });
  });

  describe("when isOnlyOwner = true", function () {
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
        _cycleTimestamp,
        this.lotteryERC20.address,
        _link,
        _coordinator,
        _keyHash,
        sellerCommission,
        _ticketPrice,
        _isOnlyOwner
      );

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
      const cycleTimestamp = await this.weeklyLottery.cycleTimestamp();
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
      const keyHash = await this.weeklyLottery.keyHash();
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
      expect(cycleTimestamp).to.equal(_cycleTimestamp.toString());
      expect(this.lotteryERC20.address).to.equal(erc20);
      expect(keyHash).to.equal(_keyHash);
      expect(ticketLastId).to.equal("0");
      expect(ticketLastNumber).to.equal("0");
      expect(ticketCount).to.equal("0");
      expect(isParticipated).to.equal(false);
      expect(participantCount).to.equal("0");
      expect(isOnlyOwner).to.equal(true);
    });

    it("Owner user can buy ticket", async function () {
      const user = this.signers[0];
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
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
      const ticketPrice = await this.weeklyLottery.ticketPrice(index);
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
});

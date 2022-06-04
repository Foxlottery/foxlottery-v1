import { expect } from "chai";
import { ethers } from "hardhat";

const _link = "0x01BE23585060835E02B77ef475b0Cc51aA1e0709";
const _coordinator = "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B";
const _keyHash =
  "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311";
const _ticketPrice = String(10 ** 19);
const _cycleTimestamp = 120;

async function mintAndApprove(
  lotteryERC20: any,
  weeklyLottery: any,
  user: any,
  tokenAmount: any
) {
  await lotteryERC20.mint(user.address, tokenAmount);
  await lotteryERC20.connect(user).approve(weeklyLottery.address, tokenAmount);
}

async function mintAndBuyTicket(
  lotteryERC20: any,
  weeklyLottery: any,
  user: any,
  tokenAmount: any,
  _ticketCount: any
) {
  await mintAndApprove(lotteryERC20, weeklyLottery, user, tokenAmount);
  await weeklyLottery.connect(user).buyTicket(_ticketCount);
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
        console.log(
          `address: ${
            user.address
          }, token amount: ${await this.lotteryERC20.balanceOf(user.address)}`
        );
      });

      this.weeklyLottery = await this.weeklyLottery.deploy(
        "weeklyLottery",
        "WLT",
        _cycleTimestamp,
        this.lotteryERC20.address,
        _link,
        _coordinator,
        _keyHash,
        _ticketPrice,
        _isOnlyOwner
      );
    });

    it("should have correct init value", async function () {
      const erc20 = await this.weeklyLottery.erc20();
      const name = await this.weeklyLottery.name();
      const symbol = await this.weeklyLottery.symbol();
      const cycleTimestamp = await this.weeklyLottery.cycleTimestamp();
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const keyHash = await this.weeklyLottery.keyHash();
      const ticketLastId = await this.weeklyLottery.ticketLastId();
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        ticketLastId.toString()
      );
      const ticketCount = await this.weeklyLottery.ticketCount(
        ticketLastId.toString()
      );
      const isParticipated = await this.weeklyLottery.isParticipated(
        this.signers[0].address
      );
      const participantCount = await this.weeklyLottery.participantCount();
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
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        user,
        tokenAmount,
        _ticketCount
      );

      // ticketLastIdが追加されていること
      const ticketLastId = await this.weeklyLottery.ticketLastId();
      expect(ticketLastId).to.equal("1");

      // ticketLastNumberがあること
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        ticketLastId.toString()
      );
      expect(ticketLastNumber).to.equal("3");

      // ticketCountが追加されていること
      const ticketCount = await this.weeklyLottery.ticketCount(
        ticketLastId.toString()
      );
      expect(ticketCount).to.equal("3");

      // isParticipatedがtrueに更新されていること
      const isParticipated = await this.weeklyLottery.isParticipated(
        user.address
      );
      expect(isParticipated).to.equal(true);

      // participantCountが更新されていること
      const participantCount = await this.weeklyLottery.participantCount();
      expect(participantCount).to.equal("1");

      // ticketIds
      const ticketIds = await this.weeklyLottery.getTicketIds(user.address);
      expect(ticketIds[0]).to.equal("1");

      // ticketBoughtAt
      const ticketBoughtAt = await this.weeklyLottery.ticketBoughtAt(
        ticketLastId
      );
      expect(ticketBoughtAt <= new Date().getTime()).to.equal(true);
    });

    it("Two user should buy ticket", async function () {
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      const user = this.signers[1];
      // first
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[0],
        tokenAmount,
        _ticketCount
      );
      // second
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[1],
        tokenAmount,
        _ticketCount
      );

      // ticketLastIdが追加されていること
      const ticketLastId = await this.weeklyLottery.ticketLastId();
      expect(ticketLastId).to.equal("2");

      // ticketLastNumberがあること
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        ticketLastId.toString()
      );
      expect(ticketLastNumber).to.equal("6");

      // ticketCountが追加されていること
      const ticketCount = await this.weeklyLottery.ticketCount(
        ticketLastId.toString()
      );
      expect(ticketCount).to.equal("3");

      // isParticipatedがtrueに更新されていること
      const isParticipated = await this.weeklyLottery.isParticipated(
        user.address
      );
      expect(isParticipated).to.equal(true);

      // participantCountが更新されていること
      const participantCount = await this.weeklyLottery.participantCount();
      expect(participantCount).to.equal("2");

      // ticketIds
      const ticketIds = await this.weeklyLottery.getTicketIds(user.address);
      expect(ticketIds[0]).to.equal("2");

      // ticketOwner
      const ticketOwner = await this.weeklyLottery.ticketOwner(ticketLastId);
      expect(ticketOwner).to.equal(user.address);

      // ticketBoughtAt
      const ticketBoughtAt = await this.weeklyLottery.ticketBoughtAt(
        ticketLastId
      );
      expect(ticketBoughtAt <= new Date().getTime()).to.equal(true);
    });

    it("Three user should buy ticket", async function () {
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      const user = this.signers[2];
      // first
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[0],
        tokenAmount,
        _ticketCount
      );
      // second
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[1],
        tokenAmount,
        _ticketCount
      );
      // third
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[2],
        tokenAmount,
        _ticketCount
      );

      // ticketLastIdが追加されていること
      const ticketLastId = await this.weeklyLottery.ticketLastId();
      expect(ticketLastId).to.equal("3");

      // ticketLastNumberがあること
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        ticketLastId.toString()
      );
      expect(ticketLastNumber).to.equal("9");

      // ticketCountが追加されていること
      const ticketCount = await this.weeklyLottery.ticketCount(
        ticketLastId.toString()
      );
      expect(ticketCount).to.equal("3");

      // isParticipatedがtrueに更新されていること
      const isParticipated = await this.weeklyLottery.isParticipated(
        user.address
      );
      expect(isParticipated).to.equal(true);

      // participantCountが更新されていること
      const participantCount = await this.weeklyLottery.participantCount();
      expect(participantCount).to.equal("3");

      // ticketIds
      const ticketIds = await this.weeklyLottery.getTicketIds(user.address);
      expect(ticketIds[0]).to.equal("3");

      // ticketOwner
      const ticketOwner = await this.weeklyLottery.ticketOwner(ticketLastId);
      expect(ticketOwner).to.equal(user.address);

      // ticketBoughtAt
      const ticketBoughtAt = await this.weeklyLottery.ticketBoughtAt(
        ticketLastId
      );
      expect(ticketBoughtAt <= new Date().getTime()).to.equal(true);
    });

    it("The same user buys ticket again.", async function () {
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      const user = this.signers[0];
      // first
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[0],
        tokenAmount,
        _ticketCount
      );
      // second
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[1],
        tokenAmount,
        _ticketCount
      );
      // third
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[2],
        tokenAmount,
        _ticketCount
      );
      // The same user buys ticket again.
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[0], // same user
        tokenAmount,
        _ticketCount
      );

      // ticketLastIdが追加されていること
      const ticketLastId = await this.weeklyLottery.ticketLastId();
      expect(ticketLastId).to.equal("4");

      // ticketLastNumberがあること
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        ticketLastId.toString()
      );
      expect(ticketLastNumber).to.equal("12");

      // ticketCountが追加されていること
      const ticketCount = await this.weeklyLottery.ticketCount(
        ticketLastId.toString()
      );
      expect(ticketCount).to.equal("3");

      // isParticipatedがtrueに更新されていること
      const isParticipated = await this.weeklyLottery.isParticipated(
        user.address
      );
      expect(isParticipated).to.equal(true);

      // participantCountが更新されていること
      const participantCount = await this.weeklyLottery.participantCount();
      expect(participantCount).to.equal("3");

      // ticketIds
      let ticketIds = await this.weeklyLottery.getTicketIds(
        this.signers[0].address
      );
      expect(ticketIds[0]).to.equal("1");
      expect(ticketIds[1]).to.equal("4");

      ticketIds = await this.weeklyLottery.getTicketIds(
        this.signers[1].address
      );
      expect(ticketIds[0]).to.equal("2");

      ticketIds = await this.weeklyLottery.getTicketIds(
        this.signers[2].address
      );
      expect(ticketIds[0]).to.equal("3");

      // ticketOwner
      const ticketOwner = await this.weeklyLottery.ticketOwner(ticketLastId);
      expect(ticketOwner).to.equal(user.address);

      // ticketBoughtAt
      const ticketBoughtAt = await this.weeklyLottery.ticketBoughtAt(
        ticketLastId
      );
      expect(ticketBoughtAt <= new Date().getTime()).to.equal(true);
    });

    it("Owner should send ticket", async function () {
      const user = this.signers[0];
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        user,
        tokenAmount,
        _ticketCount
      );

      await this.weeklyLottery.sendTicket(0, this.signers[1].address);
      // ticketIds
      // let ticketIds = await this.weeklyLottery.getTicketIds(
      //   this.signers[0].address
      // );
      // console.log(ticketIds);

      // ticketIds = await this.weeklyLottery.getTicketIds(this.signers[1].address);
      // console.log(ticketIds);
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
        console.log(
          `address: ${
            user.address
          }, token amount: ${await this.lotteryERC20.balanceOf(user.address)}`
        );
      });
      this.weeklyLottery = await this.weeklyLottery.deploy(
        "weeklyLottery",
        "WLT",
        _cycleTimestamp,
        this.lotteryERC20.address,
        _link,
        _coordinator,
        _keyHash,
        _ticketPrice,
        _isOnlyOwner
      );
    });

    it("should have correct init value", async function () {
      const erc20 = await this.weeklyLottery.erc20();
      const name = await this.weeklyLottery.name();
      const symbol = await this.weeklyLottery.symbol();
      const cycleTimestamp = await this.weeklyLottery.cycleTimestamp();
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const keyHash = await this.weeklyLottery.keyHash();
      const ticketLastId = await this.weeklyLottery.ticketLastId();
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        ticketLastId.toString()
      );
      const ticketCount = await this.weeklyLottery.ticketCount(
        ticketLastId.toString()
      );
      const isParticipated = await this.weeklyLottery.isParticipated(
        this.signers[0].address
      );
      const participantCount = await this.weeklyLottery.participantCount();
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
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        user,
        tokenAmount,
        _ticketCount
      );

      // ticketLastIdが追加されていること
      const ticketLastId = await this.weeklyLottery.ticketLastId();
      expect(ticketLastId).to.equal("1");

      // ticketLastNumberがあること
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        ticketLastId.toString()
      );
      expect(ticketLastNumber).to.equal("3");

      // ticketCountが追加されていること
      const ticketCount = await this.weeklyLottery.ticketCount(
        ticketLastId.toString()
      );
      expect(ticketCount).to.equal("3");

      // isParticipatedがtrueに更新されていること
      const isParticipated = await this.weeklyLottery.isParticipated(
        user.address
      );
      expect(isParticipated).to.equal(true);

      // participantCountが更新されていること
      const participantCount = await this.weeklyLottery.participantCount();
      expect(participantCount).to.equal("1");

      // ticketIds
      const ticketIds = await this.weeklyLottery.getTicketIds(user.address);
      expect(ticketIds[0]).to.equal("1");

      // ticketOwner
      const ticketOwner = await this.weeklyLottery.ticketOwner(ticketLastId);
      expect(ticketOwner).to.equal(user.address);

      // ticketBoughtAt
      const ticketBoughtAt = await this.weeklyLottery.ticketBoughtAt(
        ticketLastId
      );
      expect(ticketBoughtAt <= new Date().getTime()).to.equal(true);
    });

    it("Non-Owner can not buy ticket", async function () {
      const ticketPrice = await this.weeklyLottery.ticketPrice();
      const _ticketCount = 3;
      const tokenAmount = String(ticketPrice * _ticketCount);

      const user = this.signers[1];
      // first
      await mintAndBuyTicket(
        this.lotteryERC20,
        this.weeklyLottery,
        this.signers[0],
        tokenAmount,
        _ticketCount
      );
      // second
      await mintAndApprove(
        this.lotteryERC20,
        this.weeklyLottery,
        user,
        tokenAmount
      );
      await expect(
        this.weeklyLottery.connect(user).buyTicket(_ticketCount)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      // ticketLastIdが追加されてないこと
      const ticketLastId = await this.weeklyLottery.ticketLastId();
      expect(ticketLastId).to.equal("1");

      // ticketLastNumberが追加されてないこと
      const ticketLastNumber = await this.weeklyLottery.ticketLastNumber(
        ticketLastId.toString()
      );
      expect(ticketLastNumber).to.equal("3");

      const ticketCount = await this.weeklyLottery.ticketCount("2");
      expect(ticketCount).to.equal("0");

      const isParticipated = await this.weeklyLottery.isParticipated(
        user.address
      );
      expect(isParticipated).to.equal(false);

      // participantCountが更新されていること
      const participantCount = await this.weeklyLottery.participantCount();
      expect(participantCount).to.equal("1");

      // ticketIds
      const ticketIds = await this.weeklyLottery.getTicketIds(user.address);
      expect(ticketIds.length).to.equal(0);

      // ticketOwner
      const ticketOwner = await this.weeklyLottery.ticketOwner("2");
      expect(ticketOwner).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });
  });
});

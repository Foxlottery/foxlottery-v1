import { ethers } from "hardhat";
import { expect } from "chai";

describe("LotteryERC20", function () {
  beforeEach(async function () {
    this.lotteryERC20 = await ethers.getContractFactory("LotteryERC20");
    this.signers = await ethers.getSigners();
    this.alice = this.signers[0];
    this.bob = this.signers[1];
    this.carol = this.signers[2];
    this.lotteryERC20 = await this.lotteryERC20.deploy();
    await this.lotteryERC20.deployed();
  });

  it("should have correct name and symbol and decimal", async function () {
    const name = await this.lotteryERC20.name();
    const symbol = await this.lotteryERC20.symbol();
    const decimals = await this.lotteryERC20.decimals();
    expect(name, "LotteryERC20");
    expect(symbol, "LE2");
    expect(decimals, "18");
  });

  it("should only allow owner to mint token", async function () {
    await this.lotteryERC20.mint(this.alice.address, "100");
    await this.lotteryERC20.mint(this.bob.address, "1000");
    await expect(
      this.lotteryERC20.connect(this.bob).mint(this.carol.address, "1000", {
        from: this.bob.address,
      })
    ).to.be.revertedWith("Ownable: caller is not the owner");
    const totalSupply = await this.lotteryERC20.totalSupply();
    const aliceBal = await this.lotteryERC20.balanceOf(this.alice.address);
    const bobBal = await this.lotteryERC20.balanceOf(this.bob.address);
    const carolBal = await this.lotteryERC20.balanceOf(this.carol.address);
    expect(totalSupply).to.equal("1100");
    expect(aliceBal).to.equal("100");
    expect(bobBal).to.equal("1000");
    expect(carolBal).to.equal("0");
  });

  it("should supply token transfers properly", async function () {
    await this.lotteryERC20.mint(this.alice.address, "100");
    await this.lotteryERC20.mint(this.bob.address, "1000");
    await this.lotteryERC20.transfer(this.carol.address, "10");
    await this.lotteryERC20
      .connect(this.bob)
      .transfer(this.carol.address, "100", {
        from: this.bob.address,
      });
    const totalSupply = await this.lotteryERC20.totalSupply();
    const aliceBal = await this.lotteryERC20.balanceOf(this.alice.address);
    const bobBal = await this.lotteryERC20.balanceOf(this.bob.address);
    const carolBal = await this.lotteryERC20.balanceOf(this.carol.address);
    expect(totalSupply, "1100");
    expect(aliceBal, "90");
    expect(bobBal, "900");
    expect(carolBal, "110");
  });

  it("should fail if you try to do bad transfers", async function () {
    await this.lotteryERC20.mint(this.alice.address, "100");
    await expect(
      this.lotteryERC20.transfer(this.carol.address, "110")
    ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    await expect(
      this.lotteryERC20.connect(this.bob).transfer(this.carol.address, "1", {
        from: this.bob.address,
      })
    ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
  });
});

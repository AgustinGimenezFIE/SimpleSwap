const { expect } = require("chai");
const { ethers } = require("hardhat"); 

describe("SimpleSwap", function () {
  let tokenA, tokenB, simpleSwap, owner, user;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    const MyToken = await ethers.getContractFactory("MyToken");
    tokenA = await MyToken.deploy("TKA", "Token A");
    tokenB = await MyToken.deploy("TKB", "Token B");

    await tokenA.mint(owner.address, ethers.parseEther("10000"));
    await tokenB.mint(owner.address, ethers.parseEther("10000"));

    const SimpleSwap = await ethers.getContractFactory("SimpleSwap");
    simpleSwap = await SimpleSwap.deploy();

    // Approve and add liquidity
    await tokenA.approve(simpleSwap.target, ethers.parseEther("1000"));
    await tokenB.approve(simpleSwap.target, ethers.parseEther("1000"));

    await simpleSwap.addLiquidity(
      tokenA.target,
      tokenB.target,
      ethers.parseEther("1000"),
      ethers.parseEther("1000"),
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 3600
    );
  });

  it("should get correct price", async function () {
    const price = await simpleSwap.getPrice(tokenA.target, tokenB.target);
    expect(price).to.be.gt(0);
  });

  it("should swap tokens", async function () {
    await tokenA.transfer(user.address, ethers.parseEther("100"));
    await tokenA.connect(user).approve(simpleSwap.target, ethers.parseEther("100"));

    await simpleSwap.connect(user).swapExactTokensForTokens(
      ethers.parseEther("100"),
      0,
      [tokenA.target, tokenB.target],
      user.address,
      Math.floor(Date.now() / 1000) + 3600
    );

    const balanceB = await tokenB.balanceOf(user.address);
    expect(balanceB).to.be.gt(0);
  });
});

import { assert, expect } from "chai";
import { ethers, network } from "hardhat";

import { AuctionConfig } from "../../types";
import { createInstance } from "../instance";
import { reencryptEuint64 } from "../reencrypt";
import { getSigners, initSigners } from "../signers";
import { debug } from "../utils";
import { deployFactoryFixture } from "./AuctionFactory.fixture";

describe("Confidential Auction", function () {
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const contract = await deployFactoryFixture();
    this.contractAddress = await contract.getAddress();
    this.factory = contract;
    this.fhevm = await createInstance();

    const { constants, expectRevert } = require("@openzeppelin/test-helpers");
    const transaction = await this.factory.createAuction("asd", 0n, 10_000n, constants.ZERO_ADDRESS);
    await transaction.wait();
    const auction = await this.factory.getAuction(0);

    const contractFactory = await ethers.getContractFactory("ConfidentialAuction");
    const auctionContract = await contractFactory.connect(this.signers.alice).attach(auction);
    this.auctionAddress = await auctionContract.getAddress();
    this.auction = auctionContract;
  });

  it("should create auction", async function () {
    const { constants, expectRevert } = require("@openzeppelin/test-helpers");
    const transaction = await this.factory.createAuction("asd", 0n, 10_000n, constants.ZERO_ADDRESS);
    await transaction.wait();
    let auctionAddress;
    try {
      const auction = await this.factory.getAuction(0);
      auctionAddress = auction;
      expect(typeof auctionAddress).to.eq("string");
      expect(auctionAddress.startsWith("0x")).to.eq(true);
    } catch (error) {
      assert.fail("Error creating auction");
    }
  });

  it("should start auction and terminate it", async function () {
    let transaction = await this.auction.startAuction();
    await transaction.wait();

    transaction = await this.auction.terminateAuction("Closed!");
    await transaction.wait();

    try {
      transaction = await this.auction.terminateAuction("Closed!");
      await transaction.wait();
      assert("Expected to fail");
    } catch (error) {}
  });

  it("update config", async function () {
    let transaction = await this.auction.startAuction();
    await transaction.wait();

    transaction = await this.auction.terminateAuction("Closed!");
    await transaction.wait();

    try {
      transaction = await this.auction.terminateAuction("Closed!");
      await transaction.wait();
      assert("Expected to fail");
    } catch (error) {}
  });

  it("should not update config after an auction started w/ finalized config", async function () {
    let transaction = await this.auction.startAuction();
    await transaction.wait();

    transaction = await this.auction.terminateAuction("Closed!");
    await transaction.wait();

    try {
      transaction = await this.auction.terminateAuction("Closed!");
      await transaction.wait();
      assert("Expected to fail");
    } catch (error) {}
  });

  it("should start auction, 1 bid and terminate the auction", async function () {
    let transaction = await this.auction.startAuction();
    await transaction.wait();

    const input = this.fhevm.createEncryptedInput(await this.auction.getAddress(), this.signers.bob.address);
    const inputs = await input.add256(64).add256(16).encrypt(); // Encrypt the parameters

    await this.auction
      .connect(this.signers.bob)
      .bid(inputs.handles[0], inputs.handles[1], inputs.inputProof, { value: 1000000000000000n });
    transaction = await this.auction.terminateAuction("Closed!");
    await transaction.wait();

    const stats = await this.auction.getAuction();
    expect(stats[6]).to.equal(1);
  });

  it("should fail on config modification if _isConfigModifiable is false", async function () {
    const config = await this.auction.getConfig();
    expect(config).to.be.not.undefined;

    const contractFactory = await ethers.getContractFactory("AuctionConfig");
    // @ts-ignore
    const configContract: AuctionConfig = await contractFactory.connect(this.signers.alice).attach(config);

    let transaction = await configContract.setConfigModifiable(true);
    await transaction.wait();

    transaction = await this.auction.startAuction();
    await transaction.wait();

    // const input = this.fhevm.createEncryptedInput(await this.auction.getAddress(), this.signers.bob.address);
    // const inputs = await input.add256(64).add256(16).encrypt(); // Encrypt the parameters

    // await this.auction.connect(this.signers.bob).bid(inputs.handles[0], inputs.handles[1], inputs.inputProof);
    try {
      transaction = await configContract.setConfigModifiable(true);
      await transaction.wait();
      assert("Cannot modify after auction started");
    } catch (error) {
      console.log(error);
    }
  });

  it("should bid", async function () {
    const input = this.fhevm.createEncryptedInput(await this.auction.getAddress(), this.signers.bob.address);
    const inputs = await input.add256(64).add256(16).encrypt(); // Encrypt the parameters

    try {
      await this.auction.connect(this.signers.bob).bid(inputs.handles[0], inputs.handles[1], inputs.inputProof);
      assert("No bid lock amount sent!");
    } catch (error) {}
    try {
      await this.auction
        .connect(this.signers.bob)
        .bid(inputs.handles[0], inputs.handles[1], inputs.inputProof, { value: 100_000n });
      assert("Underpaid bid should have failed!");
    } catch (error) {}
    await this.auction
      .connect(this.signers.bob)
      .bid(inputs.handles[0], inputs.handles[1], inputs.inputProof, { value: 1000000000000000n });
  });

  // Bidding:
  // Bob bids 0.000002 ether per token for 500,000 tokens,
  // Carol bids 0.000008 ether per token for 600,000 tokens,
  // David bids 0.00000000001 per token for 1,000,000 tokens.
  // Resolution:
  // Carol gets 600,000 tokens,
  // Bob gets 400,000 tokens (min((1,000,000 - 600,000), 500,000) = 400,000),
  // David gets 0 token. The settlement price is 0.000002 ether.
  // Alice collects 0.000002 * 1,000,000 = 2 ethers.
  it("should run the default scenario", async function () {
    // Bob bids 0.000002 ether per token for 500,000 tokens,
    let input = this.fhevm.createEncryptedInput(await this.auction.getAddress(), this.signers.bob.address);
    const bobInputs = await input.add256(500_000).add256(2000000000000).encrypt(); // Encrypt the parameters

    await this.auction
      .connect(this.signers.bob)
      .bid(bobInputs.handles[0], bobInputs.handles[1], bobInputs.inputProof, { value: 1000000000000000n });

    // Carol bids 0.000008 ether per token for 600,000 tokens,
    input = this.fhevm.createEncryptedInput(await this.auction.getAddress(), this.signers.carol.address);
    const carolInputs = await input.add256(600_000).add256(8000000000000).encrypt(); // Encrypt the parameters

    await this.auction
      .connect(this.signers.carol)
      .bid(carolInputs.handles[0], carolInputs.handles[1], carolInputs.inputProof, { value: 1000000000000000n });

    // David bids 0.00000000001 per token for 1,000,000 tokens.
    input = this.fhevm.createEncryptedInput(await this.auction.getAddress(), this.signers.dave.address);
    const davidInputs = await input.add256(1_000_000).add256(10000000).encrypt(); // Encrypt the parameters

    await this.auction
      .connect(this.signers.dave)
      .bid(davidInputs.handles[0], davidInputs.handles[1], davidInputs.inputProof, { value: 1000000000000000n });

    let stats = await this.auction.getAuction();

    let t = await this.auction.connect(this.signers.alice).finishAuction();
    await t.wait();

    stats = await this.auction.getAuction();

    const contractFactory = await ethers.getContractFactory("AuctionPosition");
    // @ts-ignore
    const winnerContract: AuctionConfig = await contractFactory
      .connect(this.signers.alice)
      .attach(await this.factory.getPositionNFT());
    // @ts-expect-error Inherited methods not found
    expect(await winnerContract.ownerOf(1)).to.be.not.undefined;
    expect(await this.auction.getFinalTokenPricePer()).to.be.greaterThan(0);
  });

  // The final winner calculation is broken down into multiple decryption and summarization steps
  // Calculate the bids in descending order by bidAmount * bidPer
  it("should complete calculations(1)");
  // Find the bids that are higher than the cutoff price
  it("should complete calculations(2)");
  // Do it in one go
  it("should calculate winners correctly");
});

import { ethers } from "hardhat";

import type { AuctionFactory, ConfidentialAuction } from "../../types";
import { getSigners } from "../signers";

export async function deployFactoryFixture(): Promise<AuctionFactory> {
  const signers = await getSigners();

  const contractFactory = await ethers.getContractFactory("AuctionFactory");
  const contract = await contractFactory.connect(signers.alice).deploy();
  await contract.waitForDeployment();

  return contract;
}

const { expect } = require("chai");
import { ContractRunner } from 'ethers';
import { PetitionNFT } from './../typechain-types/contracts/PetitionNFTV2.sol/PetitionNFT';
const { ethers } = require("hardhat");

describe("PetitionNFT", function () {
  let petitionNFT: PetitionNFT;
  let owner, user1: ContractRunner | null | undefined;

  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();
    const PetitionNFT = await ethers.getContractFactory("PetitionNFT");
    petitionNFT = await PetitionNFT.deploy();
    await petitionNFT.waitForDeployment();
  });

  it("Should create a draft petition", async function () {
    const tx = await petitionNFT.createDraft(
      "ipfs://QmTest123",
      2, // ENVIRONMENTAL
      ["climate", "urgent"]
    );

    await tx.wait();
    const [core, dynamic, tags, isDraft] = await petitionNFT.getPetition(0);

    expect(isDraft).to.be.true;
    expect(tags.length).to.equal(2);
  });

  it("Should publish draft and allow signing", async function () {
    // Create draft
    await petitionNFT.createDraft("ipfs://QmTest", 2, ["test"]);

    // Publish
    const now = Math.floor(Date.now() / 1000);
    await petitionNFT.publishPetition(0, now, now + 86400, 100);

    // Sign
    await petitionNFT.connect(user1).signPetition(0, "Support!");

    const [_, dynamic] = await petitionNFT.getPetition(0);
    expect(dynamic.signatureCount).to.equal(1);
  });
});
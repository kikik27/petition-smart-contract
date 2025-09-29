import { expect } from "chai";
import { ethers } from "hardhat";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ContractTransactionResponse } from "ethers";
import { Petition } from "../typechain-types";

describe("Petition Contract", function () {

  // Fixture to deploy the contract before each test
  async function deployPetitionFixture() {
    const [owner, signer1, signer2, signer3] = await ethers.getSigners();

    const Petition = await ethers.getContractFactory("Petition");
    const petition = await Petition.deploy();

    return { petition, owner, signer1, signer2, signer3 };
  }

  // Helper function to create a petition
  async function createTestPetition(petition: Petition & { deploymentTransaction(): ContractTransactionResponse; }, owner: HardhatEthersSigner) {
    const currentTime = await time.latest();
    const startDate = currentTime + 100; // starts in 100 seconds
    const endDate = currentTime + 86400; // ends in 1 day

    const tx = await petition.connect(owner).createPetition(
      "Save the Environment",
      "We need to take action now to protect our planet",
      "https://example.com/image.jpg",
      startDate,
      endDate
    );

    return { tx, startDate, endDate };
  }

  describe("Deployment", function () {
    it("Should deploy successfully", async function () {
      const { petition } = await loadFixture(deployPetitionFixture);
      expect(await petition.getTotalPetitions()).to.equal(0);
    });
  });

  describe("Create Petition", function () {
    it("Should create a petition successfully", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      const { tx } = await createTestPetition(petition, owner);

      await expect(tx).to.emit(petition, "PetitionCreated");
      expect(await petition.getTotalPetitions()).to.equal(1);
    });

    it("Should store petition data correctly", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      const petitionData = await petition.getPetition(0);

      expect(petitionData.id).to.equal(0);
      expect(petitionData.owner).to.equal(owner.address);
      expect(petitionData.title).to.equal("Save the Environment");
      expect(petitionData.description).to.equal("We need to take action now to protect our planet");
      expect(petitionData.imageUrl).to.equal("https://example.com/image.jpg");
      expect(petitionData.signatureCount).to.equal(0);
      expect(petitionData.isActive).to.equal(true);
    });

    it("Should fail if title is empty", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      const currentTime = await time.latest();

      await expect(
        petition.connect(owner).createPetition(
          "",
          "Description",
          "image.jpg",
          currentTime + 100,
          currentTime + 86400
        )
      ).to.be.revertedWith("Title cannot be empty");
    });

    it("Should fail if description is empty", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      const currentTime = await time.latest();

      await expect(
        petition.connect(owner).createPetition(
          "Title",
          "",
          "image.jpg",
          currentTime + 100,
          currentTime + 86400
        )
      ).to.be.revertedWith("Description cannot be empty");
    });

    it("Should fail if end date is before start date", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      const currentTime = await time.latest();

      await expect(
        petition.connect(owner).createPetition(
          "Title",
          "Description",
          "image.jpg",
          currentTime + 86400,
          currentTime + 100
        )
      ).to.be.revertedWith("End date must be after start date");
    });

    it("Should fail if end date is in the past", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      const currentTime = await time.latest();

      await expect(
        petition.connect(owner).createPetition(
          "Title",
          "Description",
          "image.jpg",
          currentTime - 200,
          currentTime - 100
        )
      ).to.be.revertedWith("End date must be in the future");
    });

    it("Should create multiple petitions", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);

      await createTestPetition(petition, owner);
      await createTestPetition(petition, signer1);

      expect(await petition.getTotalPetitions()).to.equal(2);
    });
  });

  describe("Sign Petition", function () {
    it("Should sign a petition successfully", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      const { startDate } = await createTestPetition(petition, owner);

      // Fast forward to start date
      await time.increaseTo(startDate + 1);

      const tx = await petition.connect(signer1).signPetition(0);

      await expect(tx).to.emit(petition, "PetitionSigned")
        .withArgs(0, signer1.address, 1);

      const petitionData = await petition.getPetition(0);
      expect(petitionData.signatureCount).to.equal(1);
    });

    it("Should track if address has signed", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      const { startDate } = await createTestPetition(petition, owner);

      await time.increaseTo(startDate + 1);

      expect(await petition.hasAddressSigned(0, signer1.address)).to.equal(false);

      await petition.connect(signer1).signPetition(0);

      expect(await petition.hasAddressSigned(0, signer1.address)).to.equal(true);
    });

    it("Should add signer to signers list", async function () {
      const { petition, owner, signer1, signer2 } = await loadFixture(deployPetitionFixture);
      const { startDate } = await createTestPetition(petition, owner);

      await time.increaseTo(startDate + 1);

      await petition.connect(signer1).signPetition(0);
      await petition.connect(signer2).signPetition(0);

      const signers = await petition.getSigners(0);
      expect(signers.length).to.equal(2);
      expect(signers[0]).to.equal(signer1.address);
      expect(signers[1]).to.equal(signer2.address);
    });

    it("Should fail if already signed", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      const { startDate } = await createTestPetition(petition, owner);

      await time.increaseTo(startDate + 1);

      await petition.connect(signer1).signPetition(0);

      await expect(
        petition.connect(signer1).signPetition(0)
      ).to.be.revertedWith("You have already signed this petition");
    });

    it("Should fail if petition hasn't started", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      await expect(
        petition.connect(signer1).signPetition(0)
      ).to.be.revertedWith("Petition has not started yet");
    });

    it("Should fail if petition has ended", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      const { endDate } = await createTestPetition(petition, owner);

      // Fast forward past end date
      await time.increaseTo(endDate + 100);

      await expect(
        petition.connect(signer1).signPetition(0)
      ).to.be.revertedWith("Petition has ended");
    });

    it("Should fail if petition is not active", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      const { startDate } = await createTestPetition(petition, owner);

      await time.increaseTo(startDate + 1);

      // Deactivate petition
      await petition.connect(owner).setPetitionStatus(0, false);

      await expect(
        petition.connect(signer1).signPetition(0)
      ).to.be.revertedWith("Petition is not active");
    });

    it("Should fail if petition doesn't exist", async function () {
      const { petition, signer1 } = await loadFixture(deployPetitionFixture);

      await expect(
        petition.connect(signer1).signPetition(999)
      ).to.be.revertedWith("Petition does not exist");
    });

    it("Should allow multiple people to sign", async function () {
      const { petition, owner, signer1, signer2, signer3 } = await loadFixture(deployPetitionFixture);
      const { startDate } = await createTestPetition(petition, owner);

      await time.increaseTo(startDate + 1);

      await petition.connect(signer1).signPetition(0);
      await petition.connect(signer2).signPetition(0);
      await petition.connect(signer3).signPetition(0);

      const petitionData = await petition.getPetition(0);
      expect(petitionData.signatureCount).to.equal(3);
    });
  });

  describe("Update Petition", function () {
    it("Should update title and log changes", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      const tx = await petition.connect(owner).updateTitle(0, "New Title");

      await expect(tx).to.emit(petition, "PetitionUpdated")
        .withArgs(0, "title", await time.latest());

      const petitionData = await petition.getPetition(0);
      expect(petitionData.title).to.equal("New Title");

      const logs = await petition.getUpdateLogs(0);
      expect(logs.length).to.equal(1);
      expect(logs[0].fieldUpdated).to.equal("title");
      expect(logs[0].oldValue).to.equal("Save the Environment");
      expect(logs[0].newValue).to.equal("New Title");
    });

    it("Should update description and log changes", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      await petition.connect(owner).updateDescription(0, "New Description");

      const petitionData = await petition.getPetition(0);
      expect(petitionData.description).to.equal("New Description");

      const logs = await petition.getUpdateLogs(0);
      expect(logs[0].fieldUpdated).to.equal("description");
    });

    it("Should update image and log changes", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      await petition.connect(owner).updateImage(0, "https://newimage.com/img.jpg");

      const petitionData = await petition.getPetition(0);
      expect(petitionData.imageUrl).to.equal("https://newimage.com/img.jpg");

      const logs = await petition.getUpdateLogs(0);
      expect(logs[0].fieldUpdated).to.equal("imageUrl");
    });

    it("Should update end date and log changes", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      const { startDate } = await createTestPetition(petition, owner);

      const newEndDate = startDate + 172800; // 2 days from start
      await petition.connect(owner).updateEndDate(0, newEndDate);

      const petitionData = await petition.getPetition(0);
      expect(petitionData.endDate).to.equal(newEndDate);

      const logs = await petition.getUpdateLogs(0);
      expect(logs[0].fieldUpdated).to.equal("endDate");
    });

    it("Should fail to update if not owner", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      await expect(
        petition.connect(signer1).updateTitle(0, "Hacked Title")
      ).to.be.revertedWith("Only petition owner can call this");
    });

    it("Should track multiple updates", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      await petition.connect(owner).updateTitle(0, "Title 1");
      await petition.connect(owner).updateDescription(0, "Desc 1");
      await petition.connect(owner).updateTitle(0, "Title 2");

      const logs = await petition.getUpdateLogs(0);
      expect(logs.length).to.equal(3);
    });

    it("Should fail to update title if empty", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      await expect(
        petition.connect(owner).updateTitle(0, "")
      ).to.be.revertedWith("Title cannot be empty");
    });

    it("Should fail to update end date if in the past", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      const pastTime = (await time.latest()) - 1000;

      await expect(
        petition.connect(owner).updateEndDate(0, pastTime)
      ).to.be.revertedWith("End date must be in the future");
    });
  });

  describe("Petition Status", function () {
    it("Should change petition status", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      const tx = await petition.connect(owner).setPetitionStatus(0, false);

      await expect(tx).to.emit(petition, "PetitionStatusChanged")
        .withArgs(0, false);

      const petitionData = await petition.getPetition(0);
      expect(petitionData.isActive).to.equal(false);
    });

    it("Should fail to change status if not owner", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      await createTestPetition(petition, owner);

      await expect(
        petition.connect(signer1).setPetitionStatus(0, false)
      ).to.be.revertedWith("Only petition owner can call this");
    });
  });

  describe("Petition Statistics", function () {
    it("Should return correct petition stats", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      const { startDate, endDate } = await createTestPetition(petition, owner);

      await time.increaseTo(startDate + 1);
      await petition.connect(signer1).signPetition(0);

      const stats = await petition.getPetitionStats(0);

      expect(stats.signatureCount).to.equal(1);
      expect(stats.isActive).to.equal(true);
      expect(stats.hasEnded).to.equal(false);
      expect(stats.hasStarted).to.equal(true);
    });

    it("Should show petition has ended", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      const { endDate } = await createTestPetition(petition, owner);

      await time.increaseTo(endDate + 100);

      const stats = await petition.getPetitionStats(0);
      expect(stats.hasEnded).to.equal(true);
    });
  });

  describe("Edge Cases", function () {
    it("Should handle petition at exact start time", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      const { startDate } = await createTestPetition(petition, owner);

      await time.increaseTo(startDate);

      await expect(
        petition.connect(signer1).signPetition(0)
      ).to.not.be.reverted;
    });

    it("Should handle petition at exact end time", async function () {
      const { petition, owner, signer1 } = await loadFixture(deployPetitionFixture);
      const { startDate, endDate } = await createTestPetition(petition, owner);

      await time.increaseTo(startDate + 1);
      await petition.connect(signer1).signPetition(0);

      await time.increaseTo(endDate);

      await expect(
        petition.connect(signer1).signPetition(0)
      ).to.not.be.reverted;
    });

    it("Should handle very long petition descriptions", async function () {
      const { petition, owner } = await loadFixture(deployPetitionFixture);
      const currentTime = await time.latest();

      const longDescription = "A".repeat(10000);

      await expect(
        petition.connect(owner).createPetition(
          "Title",
          longDescription,
          "image.jpg",
          currentTime + 100,
          currentTime + 86400
        )
      ).to.not.be.reverted;
    });
  });
});
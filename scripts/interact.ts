import hre from "hardhat";
import { ethers } from "hardhat";

async function main() {
  console.log("🔗 Connecting to PetitionNFT contract...\n");

  const fs = require("fs");
  let contractAddress: string;

  try {
    const deploymentInfo = JSON.parse(
      fs.readFileSync("./deployment-info.json", "utf8")
    );
    contractAddress = deploymentInfo.address;
  } catch {
    console.error("❌ deployment-info.json not found. Please deploy first.");
    process.exit(1);
  }

  const [owner, user1, user2] = await hre.ethers.getSigners();
  const PetitionNFT = await hre.ethers.getContractFactory("PetitionNFT");
  const petition = PetitionNFT.attach(contractAddress);

  console.log("📍 Contract Address:", contractAddress);
  console.log("👤 Owner:", owner.address);
  console.log("👤 User1:", user1.address);
  console.log("👤 User2:", user2.address);
  console.log("");

  // Get blockchain timestamp
  const latestBlock = await ethers.provider.getBlock("latest");
  const currentBlockTime = latestBlock!.timestamp;

  const startDate = currentBlockTime;
  const endDate = currentBlockTime + 86400 * 30; // 30 days
  const targetSignatures = 100;

  console.log("📝 Creating petition #1 (ID will be AUTO-GENERATED)...");

  // Create Petition 1
  const tx1 = await petition.createPetition(
    "ipfs://QmExample123456789",
    0, // SOCIAL category
    ["climate", "education", "health"],
    startDate,
    endDate,
    targetSignatures
  );

  console.log("⏳ Waiting for transaction...");
  const receipt1 = await tx1.wait();

  // Extract petitionId dari event
  const createEvent1 = receipt1.logs.find((log: any) => {
    try {
      const parsed = petition.interface.parseLog(log);
      return parsed?.name === "PetitionCreated";
    } catch {
      return false;
    }
  });

  const parsedEvent1 = petition.interface.parseLog(createEvent1!);
  const petitionId1 = parsedEvent1!.args[0];

  console.log("✅ Petition #1 created!");
  console.log("🆔 Petition ID:", petitionId1);
  console.log("📝 Transaction Hash:", tx1.hash);
  console.log("");

  // Create Petition 2
  console.log("📝 Creating petition #2...");
  const tx2 = await petition
    .connect(user1)
    .createPetition(
      "ipfs://QmExample987654321",
      2, // ENVIRONMENTAL category
      ["nature", "wildlife", "conservation"],
      startDate,
      endDate + 86400 * 10, // 40 days
      50
    );

  const receipt2 = await tx2.wait();
  const createEvent2 = receipt2.logs.find((log: any) => {
    try {
      const parsed = petition.interface.parseLog(log);
      return parsed?.name === "PetitionCreated";
    } catch {
      return false;
    }
  });

  const parsedEvent2 = petition.interface.parseLog(createEvent2!);
  const petitionId2 = parsedEvent2!.args[0];

  console.log("✅ Petition #2 created!");
  console.log("🆔 Petition ID:", petitionId2);
  console.log("📝 Transaction Hash:", tx2.hash);
  console.log("");

  // Create Petition 3
  console.log("📝 Creating petition #3...");
  const tx3 = await petition
    .connect(user2)
    .createPetition(
      "ipfs://QmExample555555555",
      4, // HEALTH category
      ["healthcare", "medicine"],
      startDate,
      endDate + 86400 * 20, // 50 days
      200
    );

  const receipt3 = await tx3.wait();
  const createEvent3 = receipt3.logs.find((log: any) => {
    try {
      const parsed = petition.interface.parseLog(log);
      return parsed?.name === "PetitionCreated";
    } catch {
      return false;
    }
  });

  const parsedEvent3 = petition.interface.parseLog(createEvent3!);
  const petitionId3 = parsedEvent3!.args[0];

  console.log("✅ Petition #3 created!");
  console.log("🆔 Petition ID:", petitionId3);
  console.log("");

  // ========== GET ALL PETITIONS ==========
  console.log("=".repeat(60));
  console.log("📋 GETTING ALL PETITIONS");
  console.log("=".repeat(60));
  console.log("");

  const allPetitions = await petition.getAllPetitions();
  console.log(`📊 Total Petitions: ${allPetitions.length}\n`);

  allPetitions.forEach((p: any, index: number) => {
    console.log(`┌─ Petition #${index + 1}`);
    console.log(`│ ID: ${p.id}`);
    console.log(`│ Owner: ${p.owner}`);
    console.log(`│ Token ID: ${p.tokenId.toString()}`);
    console.log(`│ Category: ${["SOCIAL", "POLITICAL", "ENVIRONMENTAL", "EDUCATION", "HEALTH"][p.category]}`);
    console.log(`│ Tags: ${p.tags.join(", ")}`);
    console.log(`│ Target: ${p.targetSignatures.toString()} signatures`);
    console.log(`│ Current: ${p.signatureCount.toString()} signatures`);
    console.log(`│ Status: ${["ACTIVE", "COMPLETED", "CANCELLED"][p.status]}`);
    console.log(`│ Created: ${new Date(Number(p.createdAt) * 1000).toISOString()}`);
    console.log(`│ End Date: ${new Date(Number(p.endDate) * 1000).toISOString()}`);
    console.log(`│ Metadata: ${p.metadataURI}`);
    console.log(`└${"─".repeat(58)}\n`);
  });

  // ========== GET ACTIVE PETITIONS ==========
  console.log("=".repeat(60));
  console.log("🔥 GETTING ACTIVE PETITIONS");
  console.log("=".repeat(60));
  console.log("");

  const activePetitions = await petition.getActivePetitions();
  console.log(`📊 Active Petitions: ${activePetitions.length}\n`);

  activePetitions.forEach((p: any, index: number) => {
    console.log(`${index + 1}. ${p.id}`);
    console.log(`   Owner: ${p.owner}`);
    console.log(`   Signatures: ${p.signatureCount}/${p.targetSignatures}`);
    console.log(`   Progress: ${p.targetSignatures > 0 ? Math.floor((Number(p.signatureCount) * 100) / Number(p.targetSignatures)) : 0}%\n`);
  });

  // ========== GET PETITIONS BY CATEGORY ==========
  console.log("=".repeat(60));
  console.log("🏷️  GETTING PETITIONS BY CATEGORY");
  console.log("=".repeat(60));
  console.log("");

  // Social category
  const socialPetitions = await petition.getPetitionsByCategory(0);
  console.log(`📌 SOCIAL Category: ${socialPetitions.length} petition(s)`);
  socialPetitions.forEach((p: any) => {
    console.log(`   - ${p.id.substring(0, 10)}... (${p.signatureCount}/${p.targetSignatures} signatures)`);
  });
  console.log("");

  // Environmental category
  const envPetitions = await petition.getPetitionsByCategory(2);
  console.log(`🌍 ENVIRONMENTAL Category: ${envPetitions.length} petition(s)`);
  envPetitions.forEach((p: any) => {
    console.log(`   - ${p.id.substring(0, 10)}... (${p.signatureCount}/${p.targetSignatures} signatures)`);
  });
  console.log("");

  // Health category
  const healthPetitions = await petition.getPetitionsByCategory(4);
  console.log(`🏥 HEALTH Category: ${healthPetitions.length} petition(s)`);
  healthPetitions.forEach((p: any) => {
    console.log(`   - ${p.id.substring(0, 10)}... (${p.signatureCount}/${p.targetSignatures} signatures)`);
  });
  console.log("");

  // ========== GET PAGINATED PETITIONS ==========
  console.log("=".repeat(60));
  console.log("📄 GETTING PAGINATED PETITIONS");
  console.log("=".repeat(60));
  console.log("");

  const page1 = await petition.getPetitionsPaginated(0, 2); // First 2
  console.log(`📄 Page 1 (offset: 0, limit: 2): ${page1.length} petition(s)`);
  page1.forEach((p: any, i: number) => {
    console.log(`   ${i + 1}. ${p.id.substring(0, 10)}... - ${p.tags.join(", ")}`);
  });
  console.log("");

  const page2 = await petition.getPetitionsPaginated(2, 2); // Next 2
  console.log(`📄 Page 2 (offset: 2, limit: 2): ${page2.length} petition(s)`);
  page2.forEach((p: any, i: number) => {
    console.log(`   ${i + 1}. ${p.id.substring(0, 10)}... - ${p.tags.join(", ")}`);
  });
  console.log("");

  // ========== SIGN PETITIONS ==========
  console.log("=".repeat(60));
  console.log("✍️  SIGNING PETITIONS");
  console.log("=".repeat(60));
  console.log("");

  // User1 signs petition #1
  console.log("✍️  User1 signing petition #1...");
  const signTx1 = await petition
    .connect(user1)
    .signPetition(petitionId1, "I support climate action!");
  await signTx1.wait();
  console.log("✅ User1 signed petition #1");

  // User2 signs petition #1
  console.log("✍️  User2 signing petition #1...");
  const signTx2 = await petition
    .connect(user2)
    .signPetition(petitionId1, "Great initiative for education!");
  await signTx2.wait();
  console.log("✅ User2 signed petition #1");

  // Owner signs petition #2
  console.log("✍️  Owner signing petition #2...");
  const signTx3 = await petition
    .connect(owner)
    .signPetition(petitionId2, "Protecting nature is important!");
  await signTx3.wait();
  console.log("✅ Owner signed petition #2");
  console.log("");

  // ========== GET USER SIGNED PETITIONS ==========
  console.log("=".repeat(60));
  console.log("👥 GETTING USER SIGNED PETITIONS");
  console.log("=".repeat(60));
  console.log("");

  const user1Signed = await petition.getUserSignedPetitions(user1.address);
  console.log(`📝 User1 signed ${user1Signed.length} petition(s):`);
  user1Signed.forEach((id: string, i: number) => {
    console.log(`   ${i + 1}. ${id.substring(0, 10)}...`);
  });
  console.log("");

  const ownerSigned = await petition.getUserSignedPetitions(owner.address);
  console.log(`📝 Owner signed ${ownerSigned.length} petition(s):`);
  ownerSigned.forEach((id: string, i: number) => {
    console.log(`   ${i + 1}. ${id.substring(0, 10)}...`);
  });
  console.log("");

  // ========== GET USER CREATED PETITIONS ==========
  console.log("=".repeat(60));
  console.log("👤 GETTING USER CREATED PETITIONS");
  console.log("=".repeat(60));
  console.log("");

  const ownerCreated = await petition.getUserCreatedPetitions(owner.address);
  console.log(`📝 Owner created ${ownerCreated.length} petition(s):`);
  ownerCreated.forEach((id: string, i: number) => {
    console.log(`   ${i + 1}. ${id}`);
  });
  console.log("");

  const user1Created = await petition.getUserCreatedPetitions(user1.address);
  console.log(`📝 User1 created ${user1Created.length} petition(s):`);
  user1Created.forEach((id: string, i: number) => {
    console.log(`   ${i + 1}. ${id}`);
  });
  console.log("");

  // ========== GET PETITION DETAILS ==========
  console.log("=".repeat(60));
  console.log("🔍 GETTING PETITION #1 DETAILS");
  console.log("=".repeat(60));
  console.log("");

  const petitionData = await petition.getPetition(petitionId1);
  console.log("Owner:", petitionData.owner);
  console.log("Token ID:", petitionData.tokenId.toString());
  console.log("Category:", petitionData.category.toString());
  console.log("Tags:", petitionData.tags.join(", "));
  console.log("Target Signatures:", petitionData.targetSignatures.toString());
  console.log("Current Signatures:", petitionData.signatureCount.toString());
  console.log("Status:", ["ACTIVE", "COMPLETED", "CANCELLED"][petitionData.status]);
  console.log("");

  // ========== GET PETITION STATS ==========
  const stats = await petition.getPetitionStats(petitionId1);
  console.log("📈 Petition #1 Stats:");
  console.log("Signature Count:", stats.signatureCount.toString());
  console.log("Status:", ["ACTIVE", "COMPLETED", "CANCELLED"][stats.status]);
  console.log("Progress:", stats.progress.toString() + "%");
  console.log("Has Started:", stats.hasStarted);
  console.log("Has Ended:", stats.hasEnded);
  console.log("Can Sign:", stats.canSign);
  console.log("");

  // ========== GET SIGNATURES ==========
  console.log("📋 Petition #1 Signatures:");
  const signatures = await petition.getSignatures(petitionId1);
  signatures.forEach((sig: any, index: number) => {
    console.log(`${index + 1}. ${sig.signer}`);
    console.log(`   Comment: ${sig.comment}`);
    console.log(`   Time: ${new Date(Number(sig.timestamp) * 1000).toISOString()}`);
  });
  console.log("");

  // ========== FINAL STATS ==========
  console.log("=".repeat(60));
  console.log("📊 FINAL STATISTICS");
  console.log("=".repeat(60));
  console.log("");

  const totalPetitions = await petition.getTotalPetitions();
  console.log("📊 Total Petitions:", totalPetitions.toString());
  console.log("🔥 Active Petitions:", activePetitions.length);
  console.log("📝 Total Signatures:",
    Number(allPetitions[0].signatureCount) +
    Number(allPetitions[1].signatureCount) +
    Number(allPetitions[2].signatureCount)
  );

  console.log("\n✅ Interaction complete!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
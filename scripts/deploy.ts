import hre from "hardhat";

async function main() {
  console.log("🚀 Deploying PetitionNFT contract...");

  const PetitionNFT = await hre.ethers.getContractFactory("PetitionNFT");
  const petition = await PetitionNFT.deploy();

  await petition.waitForDeployment();

  const address = await petition.getAddress();
  console.log("✅ PetitionNFT deployed to:", address);

  // Save deployment info
  const fs = require("fs");
  const deploymentInfo = {
    address: address,
    network: hre.network.name,
    deployer: (await hre.ethers.getSigners())[0].address,
    timestamp: new Date().toISOString(),
  };

  fs.writeFileSync(
    "./deployment-info.json",
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("\n💾 Deployment info saved to deployment-info.json");

  // Verify on Etherscan (if not localhost)
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("\n⏳ Waiting for block confirmations...");
    await petition.deploymentTransaction()?.wait(6);

    try {
      console.log("🔍 Verifying contract on Etherscan...");
      await hre.run("verify:verify", {
        address: address,
        constructorArguments: [],
      });
      console.log("✅ Contract verified!");
    } catch (error: any) {
      if (error.message.includes("Already Verified")) {
        console.log("✅ Contract already verified!");
      } else {
        console.error("❌ Verification failed:", error);
      }
    }
  }

  console.log("\n🎉 Deployment complete!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

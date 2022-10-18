import { ethers } from "hardhat";

async function main() {
  const Ethernel = await ethers.getContractFactory("Ethernel");
  const ethernel = await Ethernel.deploy(
    "0xda3226c96D370ebbd234C4205e9f9677D37D2F1A"
  );

  await ethernel.deployed();

  console.log(`Deployed. Address: ${ethernel.address}`);
}

main().catch((error) => {
  console.error(error);

  process.exitCode = 1;
});

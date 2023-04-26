// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  // const lockedAmount = hre.ethers.utils.parseEther("0.001");

  const quadraticVoting_contract = await hre.ethers.getContractFactory("quadraticVoting");
  const quadraticVoting = await quadraticVoting_contract.deploy();

  await quadraticVoting.deployed();

  console.log(
    "Contract deployed: ", quadraticVoting
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// this is to update the front end after the contract is deployed
const { ethers, network } = require("hardhat");
const fs = require("fs");

const FRONT_END_ADDRESSES_FILE = "../nextjs-smartcontract-lottery/constants/contractAddresses.json";
const FRONT_END_ABI_FILE = "../nextjs-smartcontract-lottery/constants/abi.json";

module.exports = async function () {
  if (process.env.UPDATE_FRONT_END) {
    console.log("Updating front end...");
    updateContractAddresses();
    updateAbi();
  }
};

// async function updateAbi() {
//   const raffle = await ethers.getContract("Raffle");
//   fs.writeFileSync(
//     FRONT_END_ABI_FILE,
//     // With the .interface.format method, we can get the abi in the format we want
//     JSON.stringify(raffle.interface.format(ethers.utils.FormatTypes.json), null, 2)
//   );
// }

async function updateAbi() {
  const raffle = await ethers.getContract("Raffle");
  fs.writeFileSync(FRONT_END_ABI_FILE, JSON.stringify(raffle.interface.fragments));
}

async function updateContractAddresses() {
  const raffle = await ethers.getContract("Raffle");
  const chainId = network.config.chainId.toString();
  const currentAddresses = JSON.parse(fs.readFileSync(FRONT_END_ADDRESSES_FILE, "utf-8"));
  if (chainId in currentAddresses) {
    // If the chainId is in the file, we add the address to the array
    if (!currentAddresses[chainId].includes(raffle.address)) {
      currentAddresses[chainId].push(raffle.address);
    }
  }
  {
    currentAddresses[chainId] = [raffle.address]; // If the chainId is not in the file, we create a new array with the address
  }
  fs.writeFileSync(FRONT_END_ADDRESSES_FILE, JSON.stringify(currentAddresses, null, 2));
}

module.exports.tags = ["FrontEnd"];

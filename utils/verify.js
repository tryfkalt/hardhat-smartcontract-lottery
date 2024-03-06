const { run } = require("hardhat");

const verify = async (contractAddress, args) => {
    console.log(`Verifying contract...`);
    try {
        await hre.run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        });
        console.log("Contract verified!");
    } catch (error) {
        if (error.message.includes("Contract source code already verified")) {
            console.log("Contract already verified");
            return;
        }
        console.log(error);
    }
};

module.exports = { verify };

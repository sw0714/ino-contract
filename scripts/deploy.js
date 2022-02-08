// const PolkaWarToken = "0xCCf84A8B29F706F01816071f386079E9B5aBac76";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const INO = await ethers.getContractFactory("INO");
  const INOContract = await INO.deploy();

  console.log("INOContract address:", INOContract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
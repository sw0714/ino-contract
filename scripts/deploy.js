// const PolkaWarToken = "0xCCf84A8B29F706F01816071f386079E9B5aBac76";

async function main() {
  const [deployer] = await ethers.getSigners();
  const owner = "0xc6fa133f3290e14Ad91C7449f8D8101A6f894E25";
  // let WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";//main
  let WETH = "0xc778417E063141139Fce010982780140Aa0cD5Ab";//test
  // let WBNB = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"; //testnet.bscscan.WBNB token address
  const URI = "https://gateway.pinata.cloud/ipfs/QmTgFELoGFsT29AVqkZq9uxmzueTJfLkZ3wUqRyLJgqn1R/{id}.json";

  console.log("Deploying contracts with the account:", deployer.address);

  const INO = await ethers.getContractFactory("INO");
  const INOContract = await INO.deploy(owner, WETH, 'PolkaBridge: INO', 'PBRI', URI);

  console.log("INOContract address:", INOContract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
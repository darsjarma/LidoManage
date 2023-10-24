const {ethers} = require("hardhat")

async function main(){
    const [deployer] = await ethers.getSigners();
    const lido_manage_factory = await ethers.getContractFactory("st_token_manage");
    const lido_manage_contract = await lido_manage_factory.deploy();
    console.log(`Deployed Contract on ${await lido_manage_contract.getAddress()} by ${deployer.address}`)
}

main().then(()=>process.exit(0)).catch((error)=>{console.error(error);process.exit(0)})
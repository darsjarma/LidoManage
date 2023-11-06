const {ethers} = require("hardhat")

async function main(){
    const [deployer] = await ethers.getSigners();
    const lidoManageFactory = await ethers.getContractFactory("StTokenManage");
    const lidoManageContract = await lidoManageFactory.deploy();
    console.log(`Deployed Contract on ${await lidoManageContract.getAddress()} by ${deployer.address}`)
}

main().then(()=>process.exit(0)).catch((error)=>{console.error(error);process.exit(0)})
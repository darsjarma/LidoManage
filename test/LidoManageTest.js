const {expect} = require("chai");
const {loadFixture} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const {ethers} = require("hardhat");
const axios = require("axios");


const IERC20ApproveAbi = [ { "inputs": [ { "internalType": "address", "name": "spender", "type": "address" }, { "internalType": "uint256", "name": "amount", "type": "uint256" } ], "name": "approve", "outputs": [ { "internalType": "bool", "name": "", "type": "bool" } ], "stateMutability": "nonpayable", "type": "function" } ]
const usdcAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'


const getQuote = async (fromChain, toChain, fromToken, toToken, fromAmount, fromAddress, toAddress) => {
    const result = await axios.get('https://li.quest/v1/quote', {
        params: {
            fromToken: fromToken,
            toToken: toToken,
            fromAddress: fromAddress,
            toAddress: toAddress,
            fromAmount: fromAmount,
            fromChain:fromChain,
            toChain:toChain,
            slippage:0.3
        }
    });
    return result.data.transactionRequest.data;
}
describe("Lido Management Contract", function(){

    async function deployLidoManageFixture(){
        const [owner, addr1, addr2] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("StTokenManage");
        const LidoManageContractInstance = await contractFactory.deploy();
        await LidoManageContractInstance.waitForDeployment();
        return {LidoManageContractInstance, owner, addr1, addr2};
    }
    describe("Lido Manage", function(){
        it("Should receive usdc, swap it for eth, submit it, shows stEth value using getTVL method and then request withdrawing a part of it", async()=>{
            const {LidoManageContractInstance, owner} = await loadFixture(deployLidoManageFixture);
            const usdcContract = await ethers.getContractAt(IERC20ApproveAbi, usdcAddress);
            const LidoManageContractInstanceString = await LidoManageContractInstance.getAddress()
            const EthToUSDCQuote = await getQuote('ETH', 'ETH', 'ETH', 'USDC', ethers.parseEther('0.1'), LidoManageContractInstanceString, owner.address);
            const UsdcToEthQuote = await getQuote('ETH', 'ETH', 'USDC', 'ETH', 10*10**6,  LidoManageContractInstanceString, LidoManageContractInstanceString);
            expect(await owner.sendTransaction({
                    to: LidoManageContractInstanceString,
                    value: ethers.parseEther("1")
            }
            )).to.changeEtherBalance([owner, LidoManageContractInstance], [-ethers.parseEther("1"),ethers.parseEther("1")])
            await LidoManageContractInstance.connect(owner).swapLifi(true, '0x'+EthToUSDCQuote.slice(10));
            let stUSDCBefore = await LidoManageContractInstance.connect(owner).getStUSDCBalance();
            await usdcContract.connect(owner).approve(LidoManageContractInstance.getAddress(), 10000000);
            let stEthBefore = await LidoManageContractInstance.connect(owner).getStEthBalance();
            await LidoManageContractInstance.connect(owner).deposit(
                '0x'+UsdcToEthQuote.slice(10),
                10000000);
            let stUSDCAfter = await LidoManageContractInstance.connect(owner).getStUSDCBalance();
            let stEthAfter = await LidoManageContractInstance.connect(owner).getStEthBalance();
            console.log(`Increased staked eth ${ethers.formatEther(stEthAfter-stEthBefore)} total staked: ${ethers.formatEther(stEthAfter)}`);
            expect(stEthAfter-stEthBefore).to.not.equal(0);
            let stValue = await LidoManageContractInstance.connect(owner).getTVL();
            console.log('stEth value in USDC is:',  Number(stValue)/(10*10**(6+18)));
            expect(stUSDCAfter-stUSDCBefore).to.equals(10000000);
            await LidoManageContractInstance.connect(owner).requestWithdrawals([100]);
            let filter = LidoManageContractInstance.filters.RequestWithdrawals
            let events = await LidoManageContractInstance.queryFilter(filter, -1)
            console.log(events[0].args.requestIDs);
        }).timeout(10000000)
    })

    it("Should revert when a non-owner calls any of the function methods", async()=>{
       const {LidoManageContractInstance, owner, addr1} = await loadFixture(deployLidoManageFixture);
            const LidoManageContractInstanceString = await LidoManageContractInstance.getAddress()
            const EthToUSDCQuote = await getQuote('ETH', 'ETH', 'ETH', 'USDC', ethers.parseEther('0.1'), LidoManageContractInstanceString, owner.address);
            const UsdcToEthQuote = await getQuote('ETH', 'ETH', 'USDC', 'ETH', 10*10**6,  LidoManageContractInstanceString, LidoManageContractInstanceString);
            expect(LidoManageContractInstance.connect(addr1).getStUSDCBalance()).to.reverted;
            expect(LidoManageContractInstance.connect(addr1).setStTokenAddress(owner.address)).to.reverted;
            expect(LidoManageContractInstance.connect(addr1).setStEthWithdrawalAddress(owner.address)).to.reverted;
            expect(LidoManageContractInstance.connect(addr1).getStEthBalance(owner.address)).to.reverted;
            expect(LidoManageContractInstance.connect(addr1).getTVL()).to.reverted;
            expect(LidoManageContractInstance.connect(addr1).requestWithdrawals([100])).to.reverted;
            expect(LidoManageContractInstance.connect(addr1).claim(1)).to.reverted;
            expect(LidoManageContractInstance.connect(addr1).swapLifi(true, EthToUSDCQuote)).to.reverted;
            expect(LidoManageContractInstance.connect(addr1).deposit('0x'+UsdcToEthQuote.slice(10), 10000000)).to.reverted;
        }
    ).timeout(100000)

})

const ethers = require('ethers');
const axios = require('axios');

const API_URL = 'https://li.quest/v1';

// Get a quote for your desired transfer
const getQuote = async (fromChain, toChain, fromToken, toToken, fromAmount, fromAddress) => {
    const result = await axios.get(`${API_URL}/quote`, {
        params: {
            fromChain,
            toChain,
            fromToken,
            toToken,
            fromAmount,
            fromAddress,
        }
    });
    return result.data;
}

// Check the status of your transfer
const getStatus = async (bridge, fromChain, toChain, txHash) => {
    const result = await axios.get(`${API_URL}/status`, {
        params: {
            bridge,
            fromChain,
            toChain,
            txHash,
        }
    });
    return result.data;
}

const fromChain = 'DAI';
const fromToken = 'USDC';
const toChain = 'POL';
const toToken = 'USDC';
const fromAmount = '1000000';
const fromAddress = 0x4b7fceBd9a645fAad26893f360Fe5b8b36B613e1;

// Set up your wallet
const provider = new ethers.providers.JsonRpcProvider('https://rpc.xdaichain.com/', 100);
const wallet = ethers.Wallet.fromMnemonic('violin again enough alien slight achieve quality fancy increase oval tired pilot').connect(
    provider
);

const run = async () => {
    const quote = await getQuote(fromChain, toChain, fromToken, toToken, fromAmount, fromAddress);
    const tx = await wallet.sendTransaction(quote.transactionRequest);

    await tx.wait();

    // Only needed for cross chain transfers
    if (fromChain !== toChain) {
        let result;
        do {
            result = await getStatus(quote.tool, fromChain, toChain, tx.hash);
        } while (result.status !== 'DONE' && result.status !== 'FAILED')
    }
}

run().then(() => {
    console.log('DONE!')
});
// Checking and setting the Allowance
// Before any transaction can be sent, it must be made sure that the user is allowed to send the requested amount from his wallet.
//     This can be achieved like this:
const { Contract } = require('ethers');

const ERC20_ABI = [
    {
        "name": "approve",
        "inputs": [
            {
                "internalType": "address",
                "name": "spender",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            }
        ],
        "outputs": [
            {
                "internalType": "bool",
                "name": "",
                "type": "bool"
            }
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "name": "allowance",
        "inputs": [
            {
                "internalType": "address",
                "name": "owner",
                "type": "address"
            },
            {
                "internalType": "address",
                "name": "spender",
                "type": "address"
            }
        ],
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    }
];

// Get the current the allowance and update if needed
const checkAndSetAllowance = async (wallet, tokenAddress, approvalAddress, amount) => {
    // Transactions with the native token don't need approval
    if (tokenAddress === ethers.constants.AddressZero) {
        return
    }

    const erc20 = new Contract(tokenAddress, ERC20_ABI, wallet);
    const allowance = await erc20.allowance(await wallet.getAddress(), approvalAddress);

    if (allowance.lt(amount)) {
        const approveTx = await erc20.approve(approvalAddress, amount);
        await approveTx.wait();
    }
}

// await checkAndSetAllowance(wallet, quote.action.fromToken.address, quote.estimate.approvalAddress, fromAmount);
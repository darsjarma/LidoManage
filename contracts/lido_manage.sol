pragma solidity ^0.8.0;

import "hardhat/console.sol";
//SPDX-License-Identifier: UNLICENSED
interface IStToken {


    function submit(address _referral) external payable returns (uint256);

    function requestWithdrawals(uint256[] calldata _amounts, address _owner) external returns (uint256[] memory requestIds);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function claimWithdrawal(uint256 _requestId) external;

    function balanceOf(address _who) external view returns (uint256);

    struct SwapData {
        address callTo;
        address approveTo;
        address sendingAssetId;
        address receivingAssetId;
        uint256 fromAmount;
        bytes callData;
        bool requiresDeposit;
    }

    function swapTokensGeneric(
        bytes32 _transactionId,
        string calldata _integrator,
        string calldata _referrer,
        address payable _receiver,
        uint256 _minAmount,
        SwapData[] calldata _swapData
        ) external payable;


//    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);
}

contract st_token_manage {

    receive() external payable {}

    fallback() external payable {}

    address public st_token_address = 0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F;
    address public st_eth_withdrawal_address = 0xCF117961421cA9e546cD7f50bC73abCdB3039533;
    address public lifi_diamond_address = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
    address public usdc_address = 0xDf0360Ad8C5ccf25095Aa97ee5F2785c8d848620;

    address private owner;

    constructor(){
        owner = msg.sender;
    }
    modifier onlyOwner{
        require(msg.sender == owner, "Not owner");
        _;
    }
    function set_owner(address _new_owner) external {
        owner = _new_owner;
    }

    function set_st_token_address(address _st_token_address) external onlyOwner {
        st_token_address = _st_token_address;
    }

    function set_st_eth_withdrawal_address(address _st_token_address) external onlyOwner {
        st_token_address = _st_token_address;
    }
//    function getTVL() external view returns(uint){
//        uint st_eth_balance = IStToken(st_token_address).balanceOf(address(this));
//        // TODO: Estmite equal value of USDC
//    }
    function requestWithdrawals(uint _amount) external returns (uint256[] memory){
        uint256[] memory amounts = new uint[](1);
        amounts[0] = _amount;
        IStToken(st_token_address).approve(st_eth_withdrawal_address, _amount);
        return IStToken(st_eth_withdrawal_address).requestWithdrawals(amounts, address(this));
    }

    function claim(uint requestId) external {
        IStToken(st_eth_withdrawal_address).claimWithdrawal(requestId);
    }

    function deposit(uint _amount, bytes calldata _swapData) external {
        IStToken(usdc_address).transferFrom(msg.sender, address(this), _amount);
        uint preSwapEthBalance = msg.sender.balance;
        (bool success,) = lifi_diamond_address.call(_swapData);
        require(success, "Swapping tokens failed");
        uint receivedEth = preSwapEthBalance - msg.sender.balance;
        IStToken(st_token_address).submit{value: receivedEth}(address(this));
    }

    function swap_lifi(bytes calldata _swapData) external {
        (
                bytes32 _transactionId,
                string memory _integrator,
                string memory _referrer,
                address payable _receiver,
                uint256 _minAmount,
                IStToken.SwapData[] memory _swapsData
        ) = abi.decode(
            _swapData,
            (
                bytes32,
                string,
                string,
                address,
                uint256,
                IStToken.SwapData[]
            )
        );
        IStToken(lifi_diamond_address).swapTokensGeneric{value:_swapsData[0].fromAmount}(
            _transactionId,
            _integrator,
            _referrer,
            _receiver,
            _minAmount,
            _swapsData
        );
    }
}

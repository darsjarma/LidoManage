//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

//import "@openzeppelin/contracts/math/SafeMath.sol"
interface IStToken {


    function submit(address _referral) external payable returns (uint256);

    function requestWithdrawals(uint256[] calldata _amounts, address _owner) external returns (uint256[] memory requestIds);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function claimWithdrawal(uint256 _requestId) external;

    function balanceOf(address account) external view returns (uint256);


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

}

contract st_token_manage {

    receive() external payable {}

    fallback() external payable {}

    address public st_token_address = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public st_eth_withdrawal_address = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
    address public lifi_diamond_address = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
    address public usdc_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address private owner;
    uint private st_usdc_balance;
    uint public st_eth_balance;
    constructor(){
        owner = msg.sender;
    }
    modifier onlyOwner{
        require(msg.sender == owner, "Not owner");
        _;
    }
    function get_st_usdc_balance() external view returns(uint){
        return st_usdc_balance;
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
    function get_st_eth_balance() external view returns(uint){
        return IStToken(st_token_address).balanceOf(address(this));
    }
    function requestWithdrawals(uint _amount) external returns (uint256[] memory){
        uint256[] memory amounts = new uint[](1);
        amounts[0] = _amount;
        IStToken(st_token_address).approve(st_eth_withdrawal_address, _amount);
        return IStToken(st_eth_withdrawal_address).requestWithdrawals(amounts, address(this));
    }

    function claim(uint requestId) external {
        IStToken(st_eth_withdrawal_address).claimWithdrawal(requestId);
    }

    function swap_lifi(bool sendsEth, bytes calldata _swapData) public {
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
        uint send_eth_amount;
        if (sendsEth==true)
            send_eth_amount = _swapsData[0].fromAmount;
        else
            send_eth_amount = 0;
        IStToken(lifi_diamond_address).swapTokensGeneric{value:send_eth_amount}(
            _transactionId,
            _integrator,
            _referrer,
            _receiver,
            _minAmount,
            _swapsData
        );
    }
    function deposit(bytes calldata _swapData, uint _amount) external{
        IStToken(usdc_address).transferFrom(msg.sender, address(this), _amount);
        uint preSwapEthBalance = address(this).balance;
        IStToken(usdc_address).approve(lifi_diamond_address, _amount);
        swap_lifi(false, _swapData);
        uint receivedEth = address(this).balance - preSwapEthBalance;
        IStToken(st_token_address).submit{value: receivedEth}(address(this));
        st_usdc_balance = st_usdc_balance + _amount;
        st_eth_balance = st_eth_balance + receivedEth;
    }

}

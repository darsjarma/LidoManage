//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

contract st_token_manage is Ownable {

    receive() external payable {}

//    fallback() external payable {}

    address internal st_token_address = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address internal st_eth_withdrawal_address = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
    address internal lifi_diamond_address = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
    address internal usdc_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint private st_usdc_balance;

    AggregatorV3Interface internal StEth_USD;
    AggregatorV3Interface internal USDC_USD;

    constructor(){
        StEth_USD = AggregatorV3Interface(0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8);
        USDC_USD = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    }

    function get_st_usdc_balance() external view onlyOwner returns(uint){
        return st_usdc_balance;
    }

    function set_st_token_address(address _st_token_address) external onlyOwner {
        st_token_address = _st_token_address;
    }

    function set_st_eth_withdrawal_address(address _st_token_address) external onlyOwner {
        st_token_address = _st_token_address;
    }
    function get_st_eth_balance() public view onlyOwner returns(uint){
        return IStToken(st_token_address).balanceOf(address(this));
    }
    function getTVL() external view onlyOwner returns(int){
        (,int StEth_USD_value,,,) = StEth_USD.latestRoundData();
        (,int USDC_USD_value,,,) = USDC_USD.latestRoundData();
        return int(get_st_eth_balance())*StEth_USD_value*10*10**6/USDC_USD_value;
    }
    function requestWithdrawals(uint[] memory _amounts) external onlyOwner returns (uint256[] memory) {
        uint sum_amounts;
        for(uint i = 0 ; i<_amounts.length; i++){
            sum_amounts+=_amounts[i];
        }
        IStToken(st_token_address).approve(st_eth_withdrawal_address, sum_amounts);
        return IStToken(st_eth_withdrawal_address).requestWithdrawals(_amounts, address(this));
    }

    function claim(uint requestId) external onlyOwner{
        IStToken(st_eth_withdrawal_address).claimWithdrawal(requestId);
    }

    function swap_lifi(bool sendsEth, bytes calldata _swapData) public onlyOwner{
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
    function deposit(bytes calldata _swapData, uint _amount) external onlyOwner{
        IStToken(usdc_address).transferFrom(msg.sender, address(this), _amount);
        uint preSwapEthBalance = address(this).balance;
        IStToken(usdc_address).approve(lifi_diamond_address, _amount);
        swap_lifi(false, _swapData);
        uint receivedEth = address(this).balance - preSwapEthBalance;
        IStToken(st_token_address).submit{value: receivedEth}(address(this));
        st_usdc_balance = st_usdc_balance + _amount;
    }
}

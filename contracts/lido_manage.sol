//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

using SafeMath for uint;

interface IStToken is IERC20{
    function submit(address _referral) external payable returns (uint256);
}


interface ILidoWithdrawal{
    function requestWithdrawals(uint256[] calldata _amounts, address _owner) external returns (uint256[] memory requestIds);
    function claimWithdrawal(uint256 _requestId) external;
}


interface ILifi{
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


contract StTokenManage is Ownable {

    receive() external payable {}

    address internal stTokenAddress = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address internal stEthWithdrawalAddress = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
    address internal lifDiamondAddress = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
    address internal usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    AggregatorV3Interface internal stEth_USDPrice;
    AggregatorV3Interface internal USDC_USDPrice;

    uint private stUSDCBalance;

    constructor(){
        stEth_USDPrice = AggregatorV3Interface(0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8);
        USDC_USDPrice = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    }

    event RequestWithdrawals(uint[] request_ids);

    function setStTokenAddress(address _st_token_address) external onlyOwner {
        stTokenAddress = _st_token_address;
    }

    function setStEthWithdrawalAddress(address _stTokenAddress) external onlyOwner {
        stTokenAddress = _stTokenAddress;
    }

    function getStEthBalance() public view onlyOwner returns(uint){
        return IStToken(stTokenAddress).balanceOf(address(this));
    }

    function getStUSDCBalance() external view onlyOwner returns(uint){
        return stUSDCBalance;
    }

    function getTVL() external view onlyOwner returns(int){
        (,int stEth_USDPriceValue,,,) = stEth_USDPrice.latestRoundData();
        (,int USDC_USDPriceValue,,,) = USDC_USDPrice.latestRoundData();
        return int(getStEthBalance())* stEth_USDPriceValue *10*10**6/USDC_USDPriceValue;
    }

    function requestWithdrawals(uint[] memory _amounts) external onlyOwner returns (uint256[] memory) {
        uint sumAmounts;
        for(uint i = 0 ; i<_amounts.length; i++){
            sumAmounts +=_amounts[i];
        }
        IStToken(stTokenAddress).approve(stEthWithdrawalAddress, sumAmounts);
        uint[] memory requestIds = ILidoWithdrawal(stEthWithdrawalAddress).requestWithdrawals(_amounts, address(this));
        emit RequestWithdrawals(requestIds);
        return requestIds;
    }

    function claim(bytes calldata _swapData, uint requestId, uint _amount) external onlyOwner{
        uint USDCBalanceBefore = IERC20(usdcAddress).balanceOf(address(this));
        ILidoWithdrawal(stEthWithdrawalAddress).claimWithdrawal(requestId);
        IERC20(usdcAddress).approve(lifDiamondAddress, _amount);
        swapLifi(false, _swapData);
        uint USDCBalanceAfter = IERC20(usdcAddress).balanceOf(address(this));
        IERC20(usdcAddress).transfer(owner(), USDCBalanceAfter - USDCBalanceBefore);
    }

    function swapLifi(bool sendsEth, bytes calldata _swapData) public onlyOwner{
        (
            bytes32 _transactionId,
            string memory _integrator,
            string memory _referrer,
            address payable _receiver,
            uint256 _minAmount,
            ILifi.SwapData[] memory _swapsData
        ) = abi.decode(
            _swapData,
            (
                bytes32,
                string,
                string,
                address,
                uint256,
                ILifi.SwapData[]
            )
        );
        uint sendEthAmount;
        if (sendsEth==true)
            sendEthAmount = _swapsData[0].fromAmount;
        else
            sendEthAmount = 0;
        ILifi(lifDiamondAddress).swapTokensGeneric{value: sendEthAmount}(
            _transactionId,
            _integrator,
            _referrer,
            _receiver,
            _minAmount,
            _swapsData
        );
    }

    function deposit(bytes calldata _swapData, uint _amount) external onlyOwner{
        IERC20(usdcAddress).transferFrom(msg.sender, address(this), _amount);
        uint preSwapEthBalance = address(this).balance;
        IERC20(usdcAddress).approve(lifDiamondAddress, _amount);
        swapLifi(false, _swapData);
        uint receivedEth = address(this).balance - preSwapEthBalance;
        IStToken(stTokenAddress).submit{value: receivedEth}(address(this));
        stUSDCBalance = stUSDCBalance.add(_amount);
    }
}


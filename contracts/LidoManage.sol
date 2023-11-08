//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/ILidoWithdrawal.sol";
import "./interfaces/ILifi.sol";
import "./interfaces/IStToken.sol";

    using SafeMath for uint;

contract StTokenManage is Ownable {

    receive() external payable {}

    address internal stTokenAddress;
    address internal stEthWithdrawalAddress;
    address internal lifDiamondAddress;
    address internal usdcAddress;

    AggregatorV3Interface internal stEth_USDPrice;
    AggregatorV3Interface internal USDC_USDPrice;

    event Deposit(uint amount);
    event RequestWithdrawals(uint[] request_ids);
    event Claim(uint requestId, uint amount);

    constructor(){
        stTokenAddress = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        stEthWithdrawalAddress = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
        lifDiamondAddress = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
        usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        stEth_USDPrice = AggregatorV3Interface(0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8);
        USDC_USDPrice = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    }

    function getStEthBalance() public view onlyOwner returns (uint){
        return IStToken(stTokenAddress).balanceOf(address(this));
    }

    function swapLifi(bool sendsEth, bytes calldata _swapData) public onlyOwner {
        _swapLifi(sendsEth, _swapData);
    }

    function setStTokenAddress(address _stTokenAddress) external onlyOwner {
        stTokenAddress = _stTokenAddress;
    }

    function setStEthWithdrawalAddress(address _stEthWithdrawalAddress) external onlyOwner {
        stEthWithdrawalAddress = _stEthWithdrawalAddress;
    }

    function setLifiDiamondAddress(address _lifiDiamondAddress) external onlyOwner {
        lifDiamondAddress = _lifiDiamondAddress;
    }

    function setUSDCAddress(address _usdcAddress) external onlyOwner {
        usdcAddress = _usdcAddress;
    }

    function setStEth_USDPrice(AggregatorV3Interface _setStEth_USDPrice) external onlyOwner {
        stEth_USDPrice = _setStEth_USDPrice;
    }

    function setUSDC_USDPrice(AggregatorV3Interface _USDC_USDPrice) external onlyOwner {
        USDC_USDPrice = _USDC_USDPrice;
    }


    function getTVL() external view onlyOwner returns (int){
        return _getTVL();
    }

    function requestWithdrawals(uint[] memory _amounts) external onlyOwner returns (uint256[] memory) {
        uint[] memory requestIds =  _requestWithdrawals(_amounts);
        emit RequestWithdrawals(requestIds);
        return requestIds;
    }

    function claim(bytes calldata _swapData, uint requestId, uint _amount) external onlyOwner {
        _claim(_swapData, requestId, _amount);
        emit Claim(requestId, _amount);
    }


    function deposit(bytes calldata _swapData, uint _amount) external onlyOwner {
        _deposit(_swapData, _amount);
        emit Deposit(_amount);
    }

    function _getTVL() internal view returns (int){
        (,int stEth_USDPriceValue,,,) = stEth_USDPrice.latestRoundData();
        (,int USDC_USDPriceValue,,,) = USDC_USDPrice.latestRoundData();
        return int(getStEthBalance()) * stEth_USDPriceValue * 10 * 10 ** 6 / USDC_USDPriceValue;
    }

    function _requestWithdrawals(uint[] memory _amounts) internal returns (uint256[] memory) {
        uint sumAmounts;
        for (uint i = 0; i < _amounts.length; i++) {
            sumAmounts += _amounts[i];
        }
        IStToken(stTokenAddress).approve(stEthWithdrawalAddress, sumAmounts);
        uint[] memory requestIds = ILidoWithdrawal(stEthWithdrawalAddress).requestWithdrawals(_amounts, address(this));
        return requestIds;
    }

    function _claim(bytes calldata _swapData, uint requestId, uint _amount) internal {
        uint USDCBalanceBefore = IERC20(usdcAddress).balanceOf(address(this));
        ILidoWithdrawal(stEthWithdrawalAddress).claimWithdrawal(requestId);
        IERC20(usdcAddress).approve(lifDiamondAddress, _amount);
        swapLifi(false, _swapData);
        uint USDCBalanceAfter = IERC20(usdcAddress).balanceOf(address(this));
        IERC20(usdcAddress).transfer(owner(), USDCBalanceAfter - USDCBalanceBefore);
    }

    function _swapLifi(bool sendsEth, bytes calldata _swapData) internal {
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
        if (sendsEth == true)
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

    function _deposit(bytes calldata _swapData, uint _amount) internal {
        IERC20(usdcAddress).transferFrom(msg.sender, address(this), _amount);
        uint preSwapEthBalance = address(this).balance;
        IERC20(usdcAddress).approve(lifDiamondAddress, _amount);
        swapLifi(false, _swapData);
        uint receivedEth = address(this).balance - preSwapEthBalance;
        IStToken(stTokenAddress).submit{value: receivedEth}(address(this));
    }
}

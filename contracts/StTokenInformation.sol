//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract StTokenInformation is Ownable{

    address internal stTokenAddress;
    address internal stEthWithdrawalAddress;
    address internal lifiDiamondAddress;
    address internal usdcAddress;

    AggregatorV3Interface internal stEth_USDPrice;
    AggregatorV3Interface internal USDC_USDPrice;

    function setStTokenAddress(address _stTokenAddress) external onlyOwner {
        stTokenAddress = _stTokenAddress;
    }

    function setStEthWithdrawalAddress(address _stEthWithdrawalAddress) external onlyOwner {
        stEthWithdrawalAddress = _stEthWithdrawalAddress;
    }

    function setLifiDiamondAddress(address _lifiDiamondAddress) external onlyOwner {
        lifiDiamondAddress = _lifiDiamondAddress;
    }

    function setUSDCAddress(address _usdcAddress) external onlyOwner {
        usdcAddress = _usdcAddress;
    }

    function setStEth_USDPriceAggregatorAddress(address _setStEth_USDPrice) external onlyOwner {
        stEth_USDPrice = AggregatorV3Interface(_setStEth_USDPrice);
    }

    function setUSDC_USDPriceAggregatorAddress(address _USDC_USDPrice) external onlyOwner {
        USDC_USDPrice = AggregatorV3Interface(_USDC_USDPrice);
    }
}
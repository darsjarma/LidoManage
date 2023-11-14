//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/ILidoWithdrawal.sol";
import "./interfaces/ILifi.sol";
import "./interfaces/IStToken.sol";
import "./StTokenInformation.sol";


contract StTokenManage is Ownable, StTokenInformation {

    receive() external payable {}

    event Deposit(uint amount);
    event RequestWithdrawals(uint[] requestIds);
    event Claim(uint requestId, uint amount);

    constructor(){
        stTokenAddress = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        stEthWithdrawalAddress = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
        lifiDiamondAddress = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
        usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        stEth_USDPrice = AggregatorV3Interface(0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8);
        USDC_USDPrice = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    }

    //public methods
    function getStEthBalance() public view onlyOwner returns (uint){
        return IStToken(stTokenAddress).balanceOf(address(this));
    }

    function swapLifi(bool sendsEth, bytes calldata _swapData) public onlyOwner returns (uint){
        return _swapLifi(sendsEth, _swapData);
    }

    //External methods
    function getTVL() external view onlyOwner returns (int){
        return _getTVL();
    }

    function requestWithdrawals(uint[] memory _amounts) external onlyOwner returns (uint256[] memory) {
        uint[] memory requestIds = _requestWithdrawals(_amounts);
        emit RequestWithdrawals(requestIds);
        return requestIds;
    }

    function claim(bytes calldata _swapData, uint requestId, uint _amount) external onlyOwner {
        _claim(_swapData, requestId);
        emit Claim(requestId, _amount);
    }


    function deposit(bytes calldata _swapData, uint _amount) external onlyOwner {
        _deposit(_swapData, _amount);
        emit Deposit(_amount);
    }

    //Internal methods:
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

    function _claim(bytes calldata _swapData, uint requestId) internal {
        ILidoWithdrawal(stEthWithdrawalAddress).claimWithdrawal(requestId);
        uint receivedUSDC = swapLifi(true, _swapData);
        require(receivedUSDC>0, "Received no USDC. Make sure _swapData in correct and sends the funds to our contract");
        IERC20(usdcAddress).transfer(owner(), receivedUSDC);
    }

    function _swapLifi(bool sendsEth, bytes calldata _swapData) internal returns (uint){
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
        uint lastIndex = _swapsData.length - 1;
        address receivingAssetId = _swapsData[lastIndex].receivingAssetId;
        uint dstBalanceBefore;
        uint desBalanceAfter;
        uint sendEthAmount;
        if (receivingAssetId == address(0x0)) //if it is receiving ETH
            dstBalanceBefore = _receiver.balance;
        else
            dstBalanceBefore = IERC20(receivingAssetId).balanceOf(address(_receiver));
        if (sendsEth == true) {
            sendEthAmount = _swapsData[0].fromAmount;
            require(address(this).balance >= sendEthAmount, "Not enough Eth in the contract");
        }
        else {
            IERC20(usdcAddress).approve(lifiDiamondAddress, _swapsData[0].fromAmount);
            sendEthAmount = 0;
        }
        ILifi(lifiDiamondAddress).swapTokensGeneric{value: sendEthAmount}(
            _transactionId,
            _integrator,
            _referrer,
            _receiver,
            _minAmount,
            _swapsData
        );
        if (receivingAssetId == address(0x0))
            desBalanceAfter = _receiver.balance;
        else
            desBalanceAfter = IERC20(receivingAssetId).balanceOf(address(_receiver));
        return desBalanceAfter - dstBalanceBefore;
    }

    function _deposit(bytes calldata _swapData, uint _amount) internal {
        IERC20(usdcAddress).transferFrom(msg.sender, address(this), _amount);
        uint receivedEth = swapLifi(false, _swapData);
        IStToken(stTokenAddress).submit{value: receivedEth}(address(this));
    }
}

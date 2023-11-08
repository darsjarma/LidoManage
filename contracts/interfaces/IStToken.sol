//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IStToken is IERC20{
    function submit(address _referral) external payable returns (uint256);
}

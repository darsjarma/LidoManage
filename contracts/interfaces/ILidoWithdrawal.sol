//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;


interface ILidoWithdrawal{
    function requestWithdrawals(uint256[] calldata _amounts, address _owner) external returns (uint256[] memory requestIds);
    function claimWithdrawal(uint256 _requestId) external;
}
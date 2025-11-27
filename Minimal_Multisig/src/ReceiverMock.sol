// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract ReceiverMock {
    error InsufficientValue();

    mapping(address => uint256) public balances;
    mapping(address => uint256) public sums;

    function setSum(uint256 x) external {
        sums[msg.sender] = x;
    }

    function deposit() external payable {
        if(msg.value == 0) {
            revert InsufficientValue();
        }
        balances[msg.sender] += msg.value;
    }

    fallback() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract GovernedVault {
    error NotGovernor();
    error TransferFailed();
    
    address public immutable governor;

    constructor(address g) {
        governor = g;
    }

    receive() external payable {}

    function withdraw(address payable to, uint256 amt) external {
        if(msg.sender != governor) {
            revert NotGovernor();
        }
        (bool ok, ) = to.call{value: amt}("");
        if(!ok) {
            revert TransferFailed();
        }
    }
}
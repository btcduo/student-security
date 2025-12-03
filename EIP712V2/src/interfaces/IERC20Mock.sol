// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20Mock {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    
    function transferFrom(address from, address to, uint256 amount) external;
}
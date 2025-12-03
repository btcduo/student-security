// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

struct UserOp {
    address sender;
    address to;
    uint256 value;
    uint256 gasLimit;
    uint256 nonce;
    uint256 deadline;
    bytes data; 
}

struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { UserOp } from "../structs/UserOp.sol";

library UserOpHash {
    bytes32 constant STRUCT_HASH = keccak256(
        "UserOp(address sender,address to,uint256 value,uint256 gasLimit,uint256 nonce,uint256 deadline,bytes data)"
    );

    function callDataHash(UserOp calldata op) internal pure returns(bytes32) {
        return keccak256(
            abi.encode(
                STRUCT_HASH,
                op.sender,
                op.to,
                op.value,
                op.gasLimit,
                op.nonce,
                op.deadline,
                keccak256(op.data)
            )
        );
    }

    function memoryHash(UserOp memory op) internal pure returns(bytes32) {
        return keccak256(
            abi.encode(
                STRUCT_HASH,
                op.sender,
                op.to,
                op.value,
                op.gasLimit,
                op.nonce,
                op.deadline,
                keccak256(op.data)
            )
        );
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ISignatureValidator {
    function isValidSignature(bytes32 digest,bytes calldata sig) external view returns(bytes4);
}
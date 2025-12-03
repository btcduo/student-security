// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ECDSA } from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract MalValidator2 {
    using ECDSA for bytes32;
    error Validator_ZeroAddr();
    error Validator_InvalidAddr();

    address public signer;

    function setSigner(address s) external {
        if(s == address(0)) {
            revert Validator_ZeroAddr();
        }
        if(s.code.length != 0) {
            revert Validator_InvalidAddr();
        }
        signer = s;
    }

    function isValidSignature(bytes32 dig, bytes calldata sig) external view returns(bytes4) {
        // address rec = dig.recover(sig);
        // if(rec == signer) {
            // return 0x1626ba7e;
        // }
        return 0x1626ba7e;
    }

    fallback() external payable {}
}
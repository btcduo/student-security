// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { UserOp } from "../structs/UserOp.sol";

interface IForwarderDigest {
    function digest(UserOp calldata op) external view returns(bytes32);
}
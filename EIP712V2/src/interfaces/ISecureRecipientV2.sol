// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { UserOp } from "../structs/UserOp.sol";
import { PermitParams } from "../structs/PermitParams.sol";

interface ISecureRecipientV2 {
    function executeWithPermit(
        UserOp calldata op,
        PermitParams calldata p,
        bytes calldata callData,
        bytes calldata sig
    ) external payable returns(bool ok, bytes memory ret);
}
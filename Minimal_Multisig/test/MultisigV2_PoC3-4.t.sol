// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MinimalMultisigV2_Rewrite } from "../src/governance/MinimalMultisigV2_Rewrite.sol";
import { ReceiverMock } from "../src/ReceiverMock.sol";

contract MultisigV2_Negative is Test {
    MinimalMultisigV2_Rewrite sig1;
    MinimalMultisigV2_Rewrite sig2;
    ReceiverMock rc;
    address a1;
    address a2;

    function setUp() public {
        sig1 = new MinimalMultisigV2_Rewrite(2);
        sig2 = new MinimalMultisigV2_Rewrite(2);
        rc = new ReceiverMock();
        a1 = makeAddr("1");
        a2 = makeAddr("2");

        vm.startPrank(address(sig1));
        sig1.setOwner(a1);
        sig1.setOwner(a2);
        vm.startPrank(address(sig2));
        sig2.setOwner(a1);
        sig2.setOwner(a2);
        vm.stopPrank();
    }

    function test_PoC_3_delegatecallSurfaceAbsent() public {
        bytes memory data = abi.encodeCall(ReceiverMock.setSum, (5));
        uint256 rcSums = rc.sums(address(sig1));
        uint256 ownerLen = sig1.ownerListLength();
        uint256 thresh = sig1.threshold();
        uint256 txId;
        txId = sig1.submit(address(rc), 0, data);
        sig1.confirm(txId);
        vm.prank(a1);
        sig1.confirm(txId);
        assertEq(rc.sums(address(sig1)), rcSums + 5);
        assertEq(sig1.ownerListLength(), ownerLen);
        assertEq(sig1.threshold(), thresh);
    }

    function test_PoC_4_replay_acrossInstances() public {
        bytes memory data = abi.encodeCall(ReceiverMock.setSum, (10));
        assertEq(rc.sums(address(sig1)), 0);
        uint256 ownerLen = sig1.ownerListLength();
        uint256 thresh = sig1.threshold();
        uint256 txId;
        txId = sig1.submit(address(rc), 0, data);
        sig1.confirm(txId);
        vm.prank(a1);
        sig1.confirm(txId);
        assertEq(rc.sums(address(sig1)), 10);
        assertEq(sig1.ownerListLength(), ownerLen);
        assertEq(sig1.threshold(), thresh);
        uint256 txId2;
        txId2 = sig2.submit(address(rc), 0, data);
        assertEq(txId, txId2);
        // txId2 = txId;
        sig2.confirm(txId2);
        vm.prank(a1);
        sig2.confirm(txId2);
        assertEq(rc.sums(address(sig2)), 10);
    }
}
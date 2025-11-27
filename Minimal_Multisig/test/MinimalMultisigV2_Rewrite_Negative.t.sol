// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MinimalMultisigV2_Rewrite } from "../src/governance/MinimalMultisigV2_Rewrite.sol";

contract MultisigV2_Negative is Test {
    MinimalMultisigV2_Rewrite sig2;
    address a1;
    address a2;

    function setUp() public {
        sig2 = new MinimalMultisigV2_Rewrite(2);
        a1 = makeAddr("1");
        a2 = makeAddr("2");

        vm.startPrank(address(sig2));
        sig2.setOwner(a1);
        sig2.setOwner(a2);
        vm.stopPrank();
    }

    function test_removeOwner_revert_UnsafeParams() public {
        uint256 txId;
        assertEq(sig2.ownerListLength(), 3);
        txId = sig2.proposeRemoveOwner(a2);
        sig2.confirm(txId);
        vm.prank(a1);
        sig2.confirm(txId);
        assertEq(sig2.ownerListLength(), sig2.threshold());
        vm.expectRevert(MinimalMultisigV2_Rewrite.UnsafeParams.selector);
        txId = sig2.proposeRemoveOwner(a1);
    }

    function test_removeOwner_revert_NotOwner() public {
        vm.startPrank(address(0xa11ce));
        vm.expectRevert(MinimalMultisigV2_Rewrite.NotOwner.selector);
        sig2.proposeAddOwner(address(0xa3));
    }

    function test_modifyThreshold_revert_Zero() public {
        vm.expectRevert(MinimalMultisigV2_Rewrite.UnsafeParams.selector);
        sig2.proposeModifyThreshold(0);
    }
    
    function test_modifyThreshold_revert_Toolarge() public {
        uint256 s = sig2.ownerListLength() + 1;
        vm.expectRevert(MinimalMultisigV2_Rewrite.UnsafeParams.selector);
        sig2.proposeModifyThreshold(s);
    }

    function test_modifyThreshold_revert_Repeated() public {
        uint256 s = sig2.threshold();
        vm.expectRevert(MinimalMultisigV2_Rewrite.ThresholdRepeated.selector);
        sig2.proposeModifyThreshold(s);
    }
}
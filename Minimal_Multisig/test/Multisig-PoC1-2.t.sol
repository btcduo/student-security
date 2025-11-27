// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MinimalMultisigV2_Rewrite } from "../src/governance/MinimalMultisigV2_Rewrite.sol";

contract Multisig_PoC1_2 is Test {
    MinimalMultisigV2_Rewrite sig2;
    address a1;
    address a2;
    address a3;

    function setUp() public {
        sig2 = new MinimalMultisigV2_Rewrite(1);
        a1 = makeAddr("1");
        a2 = makeAddr("2");
        a3 = makeAddr("3");
        uint256 txId = sig2.proposeAddOwner(a1);
        sig2.confirm(txId);
        txId = sig2.proposeModifyThreshold(2);
        sig2.confirm(txId);
        vm.deal(address(sig2), 2 ether);
    }

    function test_PoC_1_lowSecurity_2of3_transferOutFunds() public {
        assertEq(sig2.ownerListLength(), 2);
        assertEq(sig2.threshold(), 2);
        uint256 txId;
        txId = sig2.proposeAddOwner(a2);
        sig2.confirm(txId);
        vm.prank(a1);
        sig2.confirm(txId);
        assertEq(sig2.ownerListLength(), 3);
        assertEq(address(sig2).balance, 2 ether);
        txId = sig2.submit(a3, 2 ether, "");
        sig2.confirm(txId);
        vm.prank(a1);
        sig2.confirm(txId);
        assertEq(a3.balance, 2 ether);
        assertEq(address(sig2).balance, 0);
    }

    function test_PoC_2_removeOwner_2of2_transferOK() public {
        uint256 txId;
        txId = sig2.proposeAddOwner(a2);
        sig2.confirm(txId);
        vm.prank(a1);
        sig2.confirm(txId);
        assertEq(sig2.ownerListLength(), 3);
        assertEq(sig2.threshold(), 2);
        txId = sig2.proposeRemoveOwner(a1);
        sig2.confirm(txId);
        vm.prank(a1);
        sig2.confirm(txId);
        assertEq(sig2.ownerListLength(), 2);
        txId = sig2.submit(a3, address(sig2).balance, "");
        sig2.confirm(txId);
        vm.prank(a2);
        sig2.confirm(txId);
        assertEq(address(sig2).balance, 0);
        assertEq(a3.balance, 2 ether);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MinimalMultisigV2_Rewrite } from "../src/governance/MinimalMultisigV2_Rewrite.sol";
import { ReceiverMock } from "../src/ReceiverMock.sol";

contract MultisigV2 is Test {
    MinimalMultisigV2_Rewrite sig2;
    ReceiverMock rc;
    address a1;
    address a2;

    function setUp() public {
        sig2 = new MinimalMultisigV2_Rewrite(2);
        rc = new ReceiverMock();
        a1 = makeAddr("1");
        a2 = makeAddr("2");
        sig2.setOwner(a1);
        sig2.setOwner(a2);
        vm.deal(a2, 3 ether);
    }

    function test_submit_confirm_execute2() public {
        bytes memory data = abi.encodeCall(ReceiverMock.deposit, ());
        uint256 id = sig2.submit(address(rc), 1 ether, data);
        vm.prank(a1);
        sig2.confirm(id);
        address t_;
        uint256 v_;
        bool e_;
        (t_, v_, , e_) = sig2.txState(id);
        assertEq(t_, address(rc));
        assertEq(v_, 1 ether);
        assertFalse(e_);
        assertEq(rc.balances(address(sig2)), 0);
        vm.prank(a2);
        sig2.confirm(id);
        ( , , , e_) = sig2.txState(id);
        assertTrue(e_);
        assertEq(rc.balances(address(sig2)), 1 ether);
    }
}
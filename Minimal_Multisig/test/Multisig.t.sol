// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MinimalMultisig } from "../src/governance/MinimalMultisig.sol";
import { ReceiverMock } from "../src/ReceiverMock.sol";

contract Multisig is Test {
    MinimalMultisig sig;
    ReceiverMock rc;
    address o1;
    address o2;
    address o3;

    function setUp() public {
        sig = new MinimalMultisig(2);
        rc = new ReceiverMock();
        o1 = makeAddr("1");
        o2 = makeAddr("2");
        o3 = makeAddr("3");
        sig.setOwner(o1, o2, o3);
        vm.deal(o3, 3 ether);
    }

    function test_submit_confirm_execute() public {
        bytes memory data = abi.encodeCall(ReceiverMock.deposit, ());
        vm.prank(o2);
        uint256 txId = sig.submit(address(rc), 1 ether, data);
        vm.prank(o1);
        sig.confirm(txId);
        assertEq(rc.balances(address(sig)), 0);
        assertFalse(sig.txState(txId));
        vm.prank(o3);
        sig.confirm{value: 1 ether}(txId);
        assertEq(rc.balances(address(sig)), 1 ether);
        assertTrue(sig.txState(txId));
    }
}
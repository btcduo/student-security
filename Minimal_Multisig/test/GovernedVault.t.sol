// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MinimalMultisigV2 } from "../src/governance/MinimalMultisigV2.sol";
import { GovernedVault } from "../src/GovernedVault.sol";

contract GoveredVault is Test {
    MinimalMultisigV2 sig2;
    GovernedVault vt;
    address a1;
    address a2;
    address a3;

    function setUp() public {
        sig2 = new MinimalMultisigV2(2);
        vt = new GovernedVault(address(sig2));
        a1 = makeAddr("1");
        a2 = makeAddr("2");
        a3 = makeAddr("receiver");
        sig2.setOwner(a1);
        sig2.setOwner(a2);
        vm.deal(a2, 3 ether);
    }

    function test_withdraw_revert_NotGovernor() public {
        vm.deal(address(this), 2 ether);
        (bool ok, ) = payable(address(vt)).call{value: 2 ether}("");
        assertTrue(ok);
        vm.expectRevert(GovernedVault.NotGovernor.selector);
        vt.withdraw(payable(a2), 1 ether);
    }

    function test_multisig_withdraw_success() public {
        vm.deal(address(this), 5 ether);
        (bool ok, ) = payable(address(vt)).call{value: 4 ether}("");
        assertTrue(ok);
        assertEq(address(vt).balance, 4 ether);
        bytes memory data = abi.encodeCall(GovernedVault.withdraw, (payable(a3), 3 ether));
        uint256 txId = sig2.submit(address(vt), 0, data);
        vm.startPrank(a1);
        sig2.confirm(txId);
        assertEq(a3.balance, 0);
        vm.startPrank(a2);
        sig2.confirm(txId);
        assertEq(a3.balance, 3 ether);
        assertEq(address(vt).balance, 1 ether);
    }
}
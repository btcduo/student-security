pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MinimalMultisigV2_Rewrite } from "../src/governance/MinimalMultisigV2_Rewrite.sol";

contract MultisigV2 is Test {
    MinimalMultisigV2_Rewrite sig2;
    address a1;
    address a2;
    address a3;

    function setUp() public {
        sig2 = new MinimalMultisigV2_Rewrite(1);
        a1 = makeAddr("1");
        a2 = makeAddr("2");
        a3 = makeAddr("3");
    }

    function test_addOwner_multisig() public {
        uint256 txId = sig2.proposeAddOwner(a1); // address(this) submits adding the 2nd owner.
        assertFalse(sig2.owners(a1));
        sig2.confirm(txId); // address(this) confirms p: 1/1.
        assertTrue(sig2.owners(a1));
        vm.startPrank(a1);
        txId = sig2.proposeAddOwner(a2); // 2nd owner submits adding the 3rd owner.
        assertFalse(sig2.owners(a2));
        sig2.confirm(txId); // 2nd owner confirms p: 1/1.
        assertTrue(sig2.owners(a2));
        txId = sig2.proposeModifyThreshold(3); // 2th owner submits modifying threshold.
        assertEq(sig2.threshold(), 1);
        sig2.confirm(txId); // 2nd owner confirms p: 1/1.
        assertEq(sig2.threshold(), 3); // threshold modification is completed;
        txId = sig2.proposeAddOwner(a3); // 2nd submits adding the 4th owner;
        assertFalse(sig2.owners(a3));
        sig2.confirm(txId); // 2nd owner confirms p: 1/3.
        vm.startPrank(a2);
        sig2.confirm(txId); // 3rd owner confirms p: 2/3.
        vm.stopPrank();
        sig2.confirm(txId); // address(this) confirms p: 3/3.
        assertTrue(sig2.owners(a3));
        vm.startPrank(a3);
        txId = sig2.proposeRemoveOwner(address(this)); // 4th owner submits removing 1st owner(address(this)).
        assertTrue(sig2.owners(address(this)));
        sig2.confirm(txId); // 4th owner confirms p: 1/3.
        vm.startPrank(a2);
        sig2.confirm(txId); // 3rd owner confirms p: 2/3.
        vm.startPrank(a1);
        sig2.confirm(txId); // 2nd owner confirms p: 3/3.
        assertFalse(sig2.owners(address(this)));
        assertEq(sig2.ownerIndex(a3), 1);
        assertEq(sig2.ownerIndex(a1), 2);
        assertEq(sig2.ownerIndex(a2), 3);
    }

}
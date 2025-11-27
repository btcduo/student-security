// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MultiSig } from "../../src/rewrite/MultiSig.sol";

contract MultiSig_Rewrite is Test {
    MultiSig ss;
    address a;
    address b;

    function setUp() public {
        a = makeAddr("a");
        b = makeAddr("b");
        ss = new MultiSig(address(this), a);
    }

    // 如果不在 removeOwner / proposeRemoveOwner 函数执行先检查 ownerList.length > threshold.
    // 当 removeOwner成功并且 ownerList.length < threshold 时 无法通过任何提案请求, 导致系统永久锁死.
    function test_PoC_2of2_removeOwner_revert() public {
        assertEq(ss.getOwnerLength(), 2);
        assertEq(ss.threshold(), 2);
        vm.expectRevert(MultiSig.UnsafeParams.selector);
        ss.proposeRemoveOwner(a);
    }

    // ownerList.length > threshold, removeOwner OK.
    // 否则 revert, 避免系统锁死.
    function test_PoC_3of2_only_remove_1_OK() public {
        uint256 txId;
        txId = ss.proposeAddOwner(b);
        ss.confirm(txId);
        vm.expectRevert(MultiSig.UnApprovedRequest.selector);
        ss.execute(txId);
        vm.prank(a);
        ss.confirm(txId);
        ss.execute(txId);
        assertEq(ss.getOwnerLength(), 3);
        assertEq(ss.threshold(), 2);
        txId = ss.proposeRemoveOwner(a);
        ss.confirm(txId);
        vm.prank(a);
        ss.confirm(txId);
        ss.execute(txId);
        assertEq(ss.getOwnerLength(), 2);
        assertEq(ss.ownerIndex(a), 0);
        vm.expectRevert(MultiSig.UnsafeParams.selector);
        ss.proposeRemoveOwner(b);
    }

    // 如果 执行 modifyThreshold 之前不先检查 ownerList.length > threshold.
    // 当 threshold > ownerList.length 时, 无法通过任何提案, 系统锁死.
    function test_PoC_threshold_1_or_aboveOwnerCount_revert() public {
        uint256 txId;
        txId = ss.proposeModifyThreshold(1);
        ss.confirm(txId);
        vm.prank(a);
        ss.confirm(txId);
        vm.expectRevert(MultiSig.CallFailed.selector);
        ss.execute(txId);
        vm.expectRevert(MultiSig.UnsafeParams.selector);
        ss.proposeModifyThreshold(5);
    }

    function test_PoC_removedOwner_notCalculate_confirmedCount() public {
        uint256 txId;
        txId = ss.proposeAddOwner(b);
        ss.confirm(txId);
        vm.prank(a);
        ss.confirm(txId);
        ss.execute(txId);
        txId = ss.proposeRemoveOwner(a);
        uint256 txId2 = ss.proposeRemoveOwner(b);
        ss.confirm(txId);
        ss.confirm(txId2);
        vm.startPrank(b);
        ss.confirm(txId);
        ss.confirm(txId2);
        vm.stopPrank();
        ss.execute(txId);
        vm.expectRevert(MultiSig.CallFailed.selector);
        ss.execute(txId2);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MultiSig } from "../../src/rewrite/MultiSig.sol";

contract MultiSig_Rewrite2 is Test {
    MultiSig ss2;
    address a;
    address b;

    function setUp() public {
        a = makeAddr("a");
        b = makeAddr("b");
        ss2 = new MultiSig(address(this), a);
    }

    // 没有onlySelft检查.
    // 任意地址(甚至不是owner)可通过 addOwner/removeOwner/modifyThreshold修改threshold和owner.
    function test_PoC_owner_try_onlySelf_revert() public {
        assertTrue(ss2.ownerIndex(address(this)) != 0);
        vm.expectRevert(MultiSig.NotSelf.selector);
        ss2.addOwner(b);
        vm.expectRevert(MultiSig.NotSelf.selector);
        ss2.removeOwner(a);
        vm.expectRevert(MultiSig.NotSelf.selector);
        ss2.modifyThreshold(3);
    }

    // 没有UnApprovedRequest检查 approved >= threshold.
    // 任意owner提案后即可通过execute使不该被执行的交易成功执行.
    function test_PoC_confirmedCount_belowThreshold_revert() public {
        uint256 txId;
        txId = ss2.proposeAddOwner(b);
        assertEq(ss2.threshold(), 2);
        assertFalse(ss2.approved(txId, address(this)));
        assertFalse(ss2.approved(txId, a));
        ss2.confirm(txId);
        assertTrue(ss2.approved(txId, address(this)));
        assertFalse(ss2.approved(txId, a));
        vm.expectRevert(MultiSig.UnApprovedRequest.selector);
        ss2.execute(txId);
    }

    // 如果多签治理函数不通过propose* 的指定入口遵循(先提案→再审核→后执行)多签治理规则.
    // 单点owner的滥用会使多签治理的存在失去应有的安全意义.
    function test_PoC_standardProgression_OK() public {
        uint256 txId;
        txId = ss2.proposeAddOwner(b);
        ss2.confirm(txId);
        vm.prank(a);
        ss2.confirm(txId);
        assertEq(ss2.getOwnerLength(), 2);
        ss2.execute(txId);
        assertEq(ss2.getOwnerLength(), 3);
        assertEq(ss2.threshold(), 2);
        txId = ss2.proposeModifyThreshold(3);
        ss2.confirm(txId);
        vm.prank(a);
        ss2.confirm(txId);
        ss2.execute(txId);
        assertEq(ss2.threshold(), ss2.getOwnerLength());
    }
}
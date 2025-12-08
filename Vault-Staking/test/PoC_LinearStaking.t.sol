// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
/// @notice vulnerable path.
import { LinearStaking_Vuln_PoC1 } from "../src/vulnerables/LinearStaking_Vuln_PoC1.sol";
/// @notice Safe path.
import { LinearStaking_Rewrite } from "../src/rewrite/LinearStaking_Rewrite.sol";
import { MinimalVault_Rewrite } from "../src/rewrite/MinimalVault_Rewrite.sol";
import { ERC20Mock } from "../src/mocks/ERC20Mock.sol";
import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract PoC_LinearStaking is Test {
    LinearStaking_Vuln_PoC1 st;
    LinearStaking_Rewrite safeSt;
    MinimalVault_Rewrite share;
    ERC20Mock reward;
    address alice;
    address bob;

    function setUp() public {
        alice = makeAddr("ALICE");
        bob = makeAddr("BOB");
        reward = new ERC20Mock();
        share = new MinimalVault_Rewrite(IERC20(address(reward)));
        st = new LinearStaking_Vuln_PoC1(IERC20(address(share)), IERC20(address(reward)));
        safeSt = new LinearStaking_Rewrite(IERC20(address(share)), IERC20(address(reward)));
        reward.mint(address(st), 8000);
        reward.mint(address(safeSt), 8000);
    }

    function _mint(uint256 val) internal {
        vm.startPrank(alice);
        reward.mint(alice, val);
        reward.approve(address(share), val);
        share.approve(address(st), val);
        share.approve(address(safeSt), val);
        vm.startPrank(bob);
        reward.mint(bob, val);
        reward.approve(address(share), val);
        share.approve(address(st), val);
        share.approve(address(safeSt), val);
        vm.stopPrank();
    }

    function test_PoC_StakinMisAcounting() public {
        _mint(200);
        st.setRewardRate(60);
        safeSt.setRewardRate(60);
        assertEq(st.lastUpdateTime(), 1);
        assertEq(safeSt.lastUpdateTime(), 1);
        vm.startPrank(alice);
        share.deposit(alice, 200);
        st.stake(100);
        safeSt.stake(100);
        skip(10);
        vm.startPrank(bob);
        share.deposit(bob, 200);
        st.stake(100);
        safeSt.stake(100);
        skip(10);
        vm.startPrank(alice);
        st.unstake(100);
        safeSt.unstake(100);
        vm.startPrank(bob);
        st.unstake(100);
        safeSt.unstake(100);
        assertEq(st.userRewards(alice), 600);
        assertEq(st.userRewards(bob), 600);
        assertEq(safeSt.userRewards(alice), 900);
        assertEq(safeSt.userRewards(bob), 300);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { MinimalVault_Rewrite } from "../src/rewrite/MinimalVault_Rewrite.sol";
import { LinearStaking_Rewrite } from "../src/rewrite/LinearStaking_Rewrite.sol";
import { ERC20Mock } from "../src/mocks/ERC20Mock.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MinimalVault is Test {
    MinimalVault_Rewrite share;
    LinearStaking_Rewrite stake;
    ERC20Mock token;
    address alice;
    address bob;

    function setUp() public {
        token = new ERC20Mock();
        share = new MinimalVault_Rewrite(IERC20(address(token)));
        stake = new LinearStaking_Rewrite(IERC20(address(share)), IERC20(address(token)));
        alice = makeAddr("ALICE");
        bob = makeAddr("BOB");
        token.mint(address(this), 10_000);
        token.approve(address(share), type(uint256).max);
        token.mint(address(stake), 5000);
    }

    function _mint(uint256 val) internal {
        token.mint(alice, val);
        vm.prank(alice);
        token.approve(address(share), val);
        token.mint(bob, val);
        vm.prank(bob);
        token.approve(address(share), val);
        _allowance(val);
    }

    function _allowance(uint256 val) internal {
        vm.prank(alice);
        share.approve(address(stake), val);
        vm.prank(bob);
        share.approve(address(stake), val);
    }
    function test_deposit_OK() public {
        assertEq(share.userShares(address(this)), 0);
        assertEq(share.totalShares(), 0);
        assertEq(share.totalUnderlying(), 0);
        share.deposit(alice, 100);
        assertEq(share.userShares(alice), 100);
        assertEq(share.totalShares(), 100);
        assertEq(share.totalUnderlying(), 100);
    }
    function test_deposit_twice_allGood() public {
        share.deposit(alice, 100);
        share.deposit(alice, 2000);
        assertEq(share.userShares(alice), 2100);
        assertEq(share.totalShares(), 2100);
        assertEq(share.totalUnderlying(), 2100);
    }
    function test_withdraw_OK() public {
        assertEq(token.balanceOf(address(this)), 10_000);
        share.deposit(alice, 100);
        share.deposit(alice, 2000);
        vm.startPrank(alice);
        share.withdraw(bob, 2100);
        assertEq(share.userShares(alice), 0);
        assertEq(share.totalShares(), 0);
        assertEq(share.totalUnderlying(), 0);
        assertEq(token.balanceOf(bob), 2100);
        assertEq(token.balanceOf(address(this)), 7900);
    }
    function test_VaultDeposit_LinearStake_OK() public {
        _mint(100);
        vm.prank(alice);
        share.deposit(alice, 100);
        vm.prank(bob);
        share.deposit(bob, 100);
        assertEq(share.balanceOf(bob), 100);
        assertEq(share.balanceOf(bob), share.balanceOf(alice));
        assertEq(share.balanceOf(alice), share.userShares(alice));
        assertEq(stake.rewardRate(), 0);
        assertEq(stake.rewardPerTokenStored(), 0);
        assertEq(stake.lastUpdateTime(), 0);
        stake.setRewardRate(60);
        vm.prank(alice);
        stake.stake(100);
        assertEq(stake.userRewards(alice), 0);
        assertEq(stake.totalStaked(), 100);
    }

    function test_VaultDeposit_skip20Sec_LinearStake_updateRewards() public {
        _mint(100);
        stake.setRewardRate(60);
        vm.startPrank(alice);
        share.deposit(alice, 100);
        stake.stake(100);
        skip(10);
        vm.startPrank(bob);
        share.deposit(bob, 100);
        stake.stake(100);
        skip(10);
        vm.stopPrank();
        vm.prank(alice);
        stake.unstake(100);
        assertEq(stake.userRewards(alice), 900);
        skip(10);
        vm.prank(bob);
        stake.unstake(100);
        assertEq(stake.userRewards(bob), 900);
    }

    function test_VaultDeposit_LinearStake_claim_exit() public {
        _mint(100);
        stake.setRewardRate(60);
        vm.startPrank(alice);
        share.deposit(alice, 100);
        stake.stake(100);
        skip(10);
        stake.claim();
        assertEq(stake.userRewards(alice), 0);
        assertEq(stake.balances(alice), 100);
        assertEq(token.balanceOf(alice), 600);
        skip(10);
        stake.exit();
        assertEq(share.balanceOf(alice), 100);
        assertEq(token.balanceOf(alice), 1200);
    }
}
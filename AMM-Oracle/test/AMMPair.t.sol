// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { AMMPair_Rewrite } from "../src/rewrite/AMMPair_Rewrite.sol";
import { HodlMock } from "../src/mocks/HodlMock.sol";
import { USDTMock } from "../src/mocks/USDTMock.sol";

contract AMMPair is Test {
    AMMPair_Rewrite pair;
    HodlMock hodl;
    USDTMock usdt;
    address funder;
    address user1;
    address user2;
    uint256 liq_init;

    function setUp() public {
        hodl = new HodlMock();
        usdt = new USDTMock();
        pair = new AMMPair_Rewrite(address(hodl), address(usdt));
        funder = makeAddr("FUNDER");
        hodl.mint(funder, 100000);
        usdt.mint(funder, 200000);
        // Total shares should be 141421;
        vm.startPrank(funder);
        hodl.approve(address(pair), type(uint112).max);
        usdt.approve(address(pair), type(uint112).max);
        pair.addLiquidity(100000, 200000, funder);
        liq_init = pair.totalSupply();
        assertEq(liq_init, 141421);
        vm.stopPrank();
    }
    
    function _makeAddr() internal {
        user1 = makeAddr("USER1");
        user2 = makeAddr("USER2");
    }

    function _sqrt(uint256 y) internal {
        pair.sqrt(y);
    }

    function _mintAndApprove(address user, uint256 amt0, uint256 amt1) internal {
        vm.startPrank(user);
        hodl.mint(user, amt0);
        hodl.approve(address(pair), amt0);
        usdt.mint(user, amt1);
        usdt.approve(address(pair), amt1);
        vm.stopPrank();
    }

    function _aprv(address spender, address user) internal {
        vm.startPrank(user);
        hodl.approve(spender, type(uint112).max);
        usdt.approve(spender, type(uint112).max);
        vm.stopPrank();
    }

    function test_addLiquidity_OK() public {
        _makeAddr();
        _mintAndApprove(user1, 1000, 2000);
        uint256 reserve0 = hodl.balanceOf(address(pair));
        uint256 reserve1 = usdt.balanceOf(address(pair));
        vm.prank(user1);
        pair.addLiquidity(1000, 2000, user2);
        uint256 lq0 = 1000 * 141421 / reserve0;
        uint256 lq1 = 2000 * 141421 / reserve1;
        assertEq(lq0, lq1);
        assertEq(pair.balanceOf(user2), lq0);
    }

    function test_removeLiquidity_OK() public {
        _makeAddr();
        _mintAndApprove(user1, 2500, 5000);
        uint256 res0 = hodl.balanceOf(address(pair));
        vm.prank(user1);
        pair.addLiquidity(500, 1000, user2);
        // resulting in liq ≈ 707 after subtracting amount 0.105 of the dust.
        uint256 liq = 500 * liq_init / res0;
        assertEq(pair.balanceOf(user2), liq);
        uint256 local_res0 = pair.reserve0();
        uint256 local_res1 = pair.reserve1();
        uint256 supply = pair.totalSupply();
        vm.prank(user2);
        pair.removeLiquidity(liq, user1);
        // resulting in repay0 ≈ 499 after subtracting amount of the dust.
        uint256 repay0 = liq * local_res0 / supply;
        // resulting in repay0 ≈ 999 after subtracting amount of the dust.
        uint256 repay1 = liq * local_res1 / supply;
        assertEq(pair.balanceOf(user2), 0);
        assertEq(hodl.balanceOf(user1), 2000 + repay0);
        assertEq(usdt.balanceOf(user1), 4000 + repay1);
    }

    function test_swap_OK() public {
        _makeAddr();
        _mintAndApprove(user1, 3214, 8188);
        uint256 res0 = pair.reserve0();
        uint256 res1 = pair.reserve1();
        vm.prank(user1);
        pair.swap(address(hodl), 2000, 1990, user2);
        assertEq(hodl.balanceOf(user1), 1214);
        uint256 amtWithFee = 2000 * 997 / 1000;
        uint256 newRes0 = amtWithFee + res0;
        uint256 amtOut = amtWithFee * res1 / newRes0;
        uint256 newRes1 = res1 - amtOut;
        assertEq(usdt.balanceOf(user2), amtOut);
        assertEq(pair.reserve0(), newRes0 + 2000 - amtWithFee);
        assertEq(pair.reserve1(), newRes1);
    }

}
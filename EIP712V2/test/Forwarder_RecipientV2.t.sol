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
import { ValidatorMock } from "../src/mocks/ValidatorMock.sol";
import { ERC20PermitMock } from "../src/mocks/ERC20PermitMock.sol";

/**
 @notice Happy test: ForwarderV2 → SecureRecipientV2 → ReceiverMockV2.
    IForwarderDigest: computes the forwarder digest.
    IDomainRegistry: provides the domainId and the forwarder address.
    UserOpHash: computes the signer's struct hash.
    UserOp: defines the signer's struct parameters.
    PermitParams: defines the token's struct parameters.
    DomainRegistryV2: binds forwarder addresses across multiple chains.
    ForwarderV2: validates UserOp parameters, clamps the safe gas limit, 
        and relays transactions to ReceiverMock.
    SecureRecipient: checks the consistency between the caller and the forwarder,
        derives the real sender from the last twenty bytes of calldata.
    ReceiverMock: fulfills user requests.
    ValidatorMock: validates the signature when `op.sender` is its address.
    ERC20PermitMock: manages user state for token transfer.
 */
contract Forwarder_RecipientV2 is Test {
    DomainRegistryV2 registry;
    IDomainRegistry reg;
    ForwarderV2 fwd;
    SecureRecipientV2 rcp;
    ReceiverMockV2 rc;
    ValidatorMock validator;
    ERC20PermitMock token0;
    address alice;
    uint256 alicePK;
    address t_owner;
    uint256 t_ownerPK;

    function setUp() public {
        registry = new DomainRegistryV2();
        reg = IDomainRegistry(address(registry));
        fwd = new ForwarderV2(reg);
        rcp = new SecureRecipientV2(reg);
        rc = new ReceiverMockV2(address(rcp));
        token0 = new ERC20PermitMock();
        validator = new ValidatorMock();
        (alice, alicePK) = makeAddrAndKey("ALICE");
        (t_owner, t_ownerPK) = makeAddrAndKey("TOKEN_OWNER");
        registry.registerDomain(block.chainid, address(fwd));
        vm.deal(address(this), 10 ether);
        validator.setSigner(alice);
    }

    function _op(uint256 val, bytes memory data) internal view returns(UserOp memory) {
        return UserOp({
            sender: alice,
            to: address(rc),
            value: val,
            gasLimit: 450_000,
            nonce: fwd.nonces(alice),
            deadline: block.timestamp + 2,
            data: data
        });
    }

    function _caOp(uint256 val, bytes memory data) internal view returns(UserOp memory) {
        return UserOp({
            sender: address(validator),
            to: address(rc),
            value: val,
            gasLimit: 450_000,
            nonce: fwd.nonces(address(validator)),
            deadline: block.timestamp + 2,
            data: data
        });
    }

    function _p(uint256 val) internal view returns(PermitParams memory) {
        uint256 dead = block.timestamp + 2;
        bytes32 dig = token0.tokenDigest(t_owner, address(rc), val, dead);
        uint8 vv;
        bytes32 rr;
        bytes32 ss;
        (vv, rr, ss) = vm.sign(t_ownerPK, dig);
        return PermitParams({
            token: address(token0),
            owner: t_owner,
            spender: address(rc),
            value: val,
            deadline: dead,
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

    function test_call_deposit_OK() public {
        UserOp memory op;
        PermitParams memory p;
        bytes memory data;
        bytes memory sig;
        bool ok;
        data = abi.encodeCall(ReceiverMockV2.deposit, ());
        op = _op(1 ether, data);
        sig = _sig(_dig(op));
        p = _p(0);
        (ok, ) = fwd.handleUserOpViaRecipientV2{value: 1 ether}(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(rc.balanceOf(alice), 1 ether);
        assertEq(address(this).balance, 9 ether);
        assertEq(fwd.nonces(alice), 1);
    }

    function test_validator_call_deposit_OK() public {
        UserOp memory op;
        PermitParams memory p;
        bytes memory data;
        bytes memory sig;
        bool ok;
        data = abi.encodeCall(ReceiverMockV2.deposit, ());
        op = _caOp(1 ether, data);
        sig = _sig(_dig(op));
        p = _p(0);
        (ok, ) = fwd.handleUserOpViaRecipientV2{value: 1 ether}(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(rc.balanceOf(address(validator)), 1 ether);
        assertEq(address(this).balance, 9 ether);
        assertEq(fwd.nonces(address(validator)), 1);
    }

    function test_call_withdraw_OK() public {
        UserOp memory op;
        PermitParams memory p;
        bytes memory data;
        bytes memory sig;
        bool ok;
        data = abi.encodeCall(ReceiverMockV2.deposit, ());
        op = _op(1 ether, data);
        sig = _sig(_dig(op));
        p = _p(0);
        (ok, ) = fwd.handleUserOpViaRecipientV2{value: 1 ether}(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(rc.balanceOf(alice), 1 ether);
        assertEq(address(this).balance, 9 ether);
        assertEq(fwd.nonces(alice), 1);
        data = abi.encodeCall(ReceiverMockV2.withdraw, (1 ether));
        op = _op(0, data);
        sig = _sig(_dig(op));
        p = _p(0);
        (ok, ) = fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(rc.balanceOf(alice), 0);
        assertEq(alice.balance, 1 ether);
        assertEq(fwd.nonces(alice), 2);
    }

    function test_validator_call_withdraw_OK() public {
        UserOp memory op;
        PermitParams memory p;
        bytes memory data;
        bytes memory sig;
        bool ok;
        data = abi.encodeCall(ReceiverMockV2.deposit, ());
        op = _caOp(1 ether, data);
        sig = _sig(_dig(op));
        p = _p(0);
        (ok, ) = fwd.handleUserOpViaRecipientV2{value: 1 ether}(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(rc.balanceOf(address(validator)), 1 ether);
        assertEq(address(this).balance, 9 ether);
        assertEq(fwd.nonces(address(validator)), 1);
        data = abi.encodeCall(ReceiverMockV2.withdraw, (1 ether));
        op = _caOp(0, data);
        sig = _sig(_dig(op));
        p = _p(0);
        (ok, ) = fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(rc.balanceOf(address(validator)), 0);
        assertEq(address(validator).balance, 1 ether);
        assertEq(fwd.nonces(address(validator)), 2);
    }

    function test_call_transferFrom_OK() public {
        token0.mintTokenOf(t_owner, 30_000);
        UserOp memory op;
        PermitParams memory p;
        bytes memory data;
        bytes memory sig;
        bool ok;
        data = abi.encodeCall(ReceiverMockV2.transferFrom, (address(token0), t_owner, alice, 100));
        op = _op(0, data);
        sig = _sig(_dig(op));
        p = _p(101);
        (ok, ) = fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(token0.allowance(t_owner, address(rc)), 1);
        assertEq(token0.balanceOf(t_owner), 29_900);
    }

    function test_validator_call_transferFrom_OK() public {
        token0.mintTokenOf(t_owner, 30_000);
        UserOp memory op;
        PermitParams memory p;
        bytes memory data;
        bytes memory sig;
        bool ok;
        data = abi.encodeCall(ReceiverMockV2.transferFrom, (address(token0), t_owner, address(validator), 100));
        op = _caOp(0, data);
        sig = _sig(_dig(op));
        p = _p(101);
        (ok, ) = fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
        assertTrue(ok);
        assertEq(token0.allowance(t_owner, address(rc)), 1);
        assertEq(token0.balanceOf(t_owner), 29_900);
        assertEq(token0.balanceOf(address(validator)), 100);
    }

    function test_call_foo_OK() public {
        UserOp memory op;
        PermitParams memory p;
        bytes memory data;
        bytes memory sig;
        bool ok;
        data = abi.encodeCall(ReceiverMockV2.foo, ());
        op = _op(0, data);
        sig = _sig(_dig(op));
        p = _p(0);
        (ok, ) = fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
        assertTrue(ok);
    }

    function test_validator_call_foo_OK() public {
        UserOp memory op;
        PermitParams memory p;
        bytes memory data;
        bytes memory sig;
        bool ok;
        data = abi.encodeCall(ReceiverMockV2.foo, ());
        op = _caOp(0, data);
        sig = _sig(_dig(op));
        p = _p(0);
        (ok, ) = fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
        assertTrue(ok);
    }
}
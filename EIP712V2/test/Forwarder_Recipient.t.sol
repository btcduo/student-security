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
import { SecureRecipient } from "../src/SecureRecipient.sol";
import { ReceiverMock } from "../src/mocks/ReceiverMock.sol";
import { ValidatorMock } from "../src/mocks/ValidatorMock.sol";
import { ERC20PermitMock } from "../src/mocks/ERC20PermitMock.sol";

/**
* @notice Test path: Forwarder → ReceiverMock;
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
@dev This path does not call `ERC20PermitMock.permit()` because, 
    `ForwarderV2` only verifies and relays transactions, and the
    `ReceiverMock` instance acts as the spender rather than the router.
*/
contract Forwarder_Recipient is Test {
    DomainRegistryV2 registry;
    IDomainRegistry reg;
    ForwarderV2 fwd;
    ReceiverMock rc;
    ValidatorMock validator;
    ERC20PermitMock token0;
    address alice;
    uint256 alicePK;
    address t_owner;
    uint256 t_ownerPK;

    function setUp() public {
        registry = new DomainRegistryV2();
        reg = IDomainRegistry(address(registry));
        token0 = new ERC20PermitMock();
        fwd = new ForwarderV2(reg);
        rc = new ReceiverMock(reg);
        validator = new ValidatorMock();
        (alice, alicePK) = makeAddrAndKey("ALICE"); 
        (t_owner, t_ownerPK) = makeAddrAndKey("TOKEN_OWNER");
        registry.registerDomain(block.chainid, address(fwd));
        vm.deal(address(this), 10 ether);
    }

    function _aliceOp(uint256 val, bytes memory data) internal view returns(UserOp memory) {
        return UserOp({
            sender: alice,
            to: address(rc),
            value: val,
            gasLimit: 450_000,
            nonce: fwd.nonces(alice),
            deadline: block.timestamp + 5,
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
            deadline: block.timestamp + 5,
            data: data
        });
    }

    function _dig(UserOp memory op) internal view returns(bytes32) {
        return fwd.digest(op);
    }

    function _sig(bytes32 dig) internal view returns(bytes memory) {
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(alicePK, dig);
        return abi.encodePacked(r, s, v);
    }

    function _p(uint256 val) internal view returns(PermitParams memory) {
        uint256 deadl = block.timestamp + 5;
        bytes32 dig = token0.tokenDigest(t_owner, address(rc), val, deadl);
        uint8 vv;
        bytes32 rr;
        bytes32 ss;
        (vv, rr, ss) = vm.sign(t_ownerPK, dig);
        return PermitParams({
            token: address(token0),
            owner: t_owner,
            spender: address(rc),
            value: val,
            deadline: deadl,
            v: vv,
            r: rr,
            s: ss
        });
    }

    /**
     @notice Happy path. 
     */
    function test_call_deposit_OK() public {
        UserOp memory op;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMock.deposit, ());
        op = _aliceOp(1 ether, data);
        sig = _sig(_dig(op));
        (bool ok, ) = fwd.handleUserOp{value: 1 ether}(op, sig);
        assertTrue(ok);
        assertEq(rc.balanceOf(alice), 1 ether);
        assertEq(fwd.nonces(alice), 1);
    }

    function test_call_withdraw_OK() public {
        UserOp memory op;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMock.deposit, ());
        op = _aliceOp(1 ether, data);
        sig = _sig(_dig(op));
        (bool ok, ) = fwd.handleUserOp{value: 1 ether}(op, sig);
        assertTrue(ok);
        assertEq(fwd.nonces(alice), 1);
        assertEq(rc.balanceOf(alice), 1 ether);
        assertEq(alice.balance, 0);
        data = abi.encodeCall(ReceiverMock.withdraw, (1 ether));
        op = _aliceOp(0, data);
        sig = _sig(_dig(op));
        (bool ok1, ) = fwd.handleUserOp(op, sig);
        assertTrue(ok1);
        assertEq(fwd.nonces(alice), 2);
        assertEq(rc.balanceOf(alice), 0);
        assertEq(address(this).balance, 9 ether);
        assertEq(alice.balance, 1 ether);
    }

    function test_validator_call_deposit_OK() public {
        UserOp memory op;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMock.deposit, ());
        op = _caOp(1 ether, data);
        sig = _sig(_dig(op));
        validator.setSigner(alice);
        (bool ok, ) = fwd.handleUserOp{value: 1 ether}(op, sig);
        assertTrue(ok);
        assertEq(rc.balanceOf(address(validator)), 1 ether);
        assertEq(fwd.nonces(address(validator)), 1);
    }

    function test_validator_call_withdraw_OK() public {
        UserOp memory op;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMock.deposit, ());
        op = _caOp(1 ether, data);
        sig = _sig(_dig(op));
        validator.setSigner(alice);
        (bool ok, ) = fwd.handleUserOp{value: 1 ether}(op, sig);
        assertTrue(ok);
        assertEq(fwd.nonces(address(validator)), 1);
        assertEq(rc.balanceOf(address(validator)), 1 ether);
        assertEq(address(validator).balance, 0);
        data = abi.encodeCall(ReceiverMock.withdraw, (1 ether));
        op = _caOp(0, data);
        sig = _sig(_dig(op));
        (bool ok1, ) = fwd.handleUserOp(op, sig);
        assertTrue(ok1);
        assertEq(fwd.nonces(address(validator)), 2);
        assertEq(rc.balanceOf(address(validator)), 0);
        assertEq(address(this).balance, 9 ether);
        assertEq(address(validator).balance, 1 ether);
    }

    function test_transferFrom_Revert_NoAllowance() public {
        UserOp memory op;
        bytes memory sig;
        bytes memory data = 
            abi.encodeCall(ReceiverMock.transferFrom, (address(token0), alice, address(this), 1));
        op = _aliceOp(0, data);
        sig = _sig(_dig(op));
        bool ok;
        bytes memory ret;
        (ok, ret) = fwd.handleUserOp(op, sig);
        assertFalse(ok);
        bytes4 sel;
        assembly {
            sel := mload(add(ret, 32))
        }
        assertEq(sel, ERC20PermitMock.InsufficientAllowance.selector);
    }

    function test_validator_transferFrom_Revert_NoAllowance() public {
        UserOp memory op;
        bytes memory sig;
        bytes memory data = 
            abi.encodeCall(ReceiverMock.transferFrom, (address(token0), alice, address(this), 1));
        op = _caOp(0, data);
        sig = _sig(_dig(op));
        validator.setSigner(alice);
        bool ok;
        bytes memory ret;
        (ok, ret) = fwd.handleUserOp(op, sig);
        assertFalse(ok);
        bytes4 sel;
        assembly {
            sel := mload(add(ret, 32))
        }
        assertEq(sel, ERC20PermitMock.InsufficientAllowance.selector);
    }

    function test_call_foo_OK() public {
        UserOp memory op;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMock.foo, ());
        op = _aliceOp(0, data);
        sig = _sig(_dig(op));
        assertEq(rc.sum(), 0);
        (bool ok, ) = fwd.handleUserOp(op, sig);
        assertTrue(ok);
        assertEq(rc.sum(), 1);
        assertEq(fwd.nonces(alice), 1);
    }
    
    function test_validator_call_foo_OK() public {
        UserOp memory op;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMock.foo, ());
        op = _caOp(0, data);
        sig = _sig(_dig(op));
        validator.setSigner(alice);
        assertEq(rc.sum(), 0);
        (bool ok, ) = fwd.handleUserOp(op, sig);
        assertTrue(ok);
        assertEq(rc.sum(), 1);
        assertEq(fwd.nonces(address(validator)), 1);
        assertEq(fwd.nonces(alice), 0);
    }
}
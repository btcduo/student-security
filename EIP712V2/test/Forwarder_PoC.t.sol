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
/// @notice Malicious contracts to test bad path.
import { MalForwarder1 } from "../src/malicious/MalForwarder1.sol";
import { MalValidator2 } from "../src/malicious/MalValidator2.sol";
import { MalReceiver4 } from "../src/malicious/MalReceiver4.sol";

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
contract Forwarder_PoC is Test {
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
    address attacker;
    uint256 attackerPK;

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
        (attacker, attackerPK) = makeAddrAndKey("ATTACKER");
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

    function _badSig(bytes32 dig) internal view returns(bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attackerPK, dig);
        return abi.encodePacked(r, s, v);
    }

    // If `setPause` is misconfigured, the system is diabled.
    function test_PoC1_Pause_DoS() public {
        fwd.setPause(true);
        UserOp memory op;
        PermitParams memory p;
        bytes memory sig;
        bytes memory data = "";
        op = _op(0, data);
        sig = _sig(_dig(op));
        p = _p(0);
        vm.expectRevert(ForwarderV2.Paused.selector);
        fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
    }

    // Relies on forwarder addresses being correctly provided by `DomainRegistryV2`.
    function test_PoC2_MalForwarder_call_RecipientV2_Revert_NotTrustedForwarder() public {
        MalForwarder1 mfwd = new MalForwarder1(reg);
        UserOp memory op;
        PermitParams memory p;
        bytes memory sig;
        bytes memory data = "";
        op = _op(0, data);
        sig = _sig(_dig(op));
        p = _p(0);
        vm.expectRevert(SecureRecipientV2.NotTrustedForwarder.selector);
        mfwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
    }

    // If the DomainRegistryV2 allows `forwarderOf` being misconfigured, the system will denial relaying transactions.
    function test_PoC3_ForwarderAddr_mismatch_Revert_BadDomainId() public {
        ForwarderV2 forgedFwd = new ForwarderV2(reg);
        registry.updateDomain(block.chainid, address(forgedFwd));
        UserOp memory op;
        PermitParams memory p;
        bytes memory sig;
        bytes memory data = "";
        op = _op(0, data);
        sig = _sig(_dig(op));
        p = _p(0);
        vm.expectRevert(ForwarderV2.BadDomainId.selector);
        fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig);
    }

    // A malicious forwarder along with a misconfigured domain binding allow relaying tampered `UserOp`.
    // The RecipientV2 validates `UserOp` params, thereby preventing forged params from upstream callers.
    function test_PoC4_MalForwarder_uncheckSig_deposit_Revert_SRC_BadSig() public {
        MalForwarder1 mfwd = new MalForwarder1(reg);
        registry.updateDomain(block.chainid, address(mfwd));
        UserOp memory op;
        PermitParams memory p;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMockV2.deposit, ());
        op = _op(1 ether, data);
        op.sender = address(0xb0b);
        sig = _sig(_dig(op));
        p = _p(0);
        vm.expectRevert(SecureRecipientV2.SRC_BadSig.selector);
        mfwd.handleUserOpViaRecipientV2{value: 1 ether}(address(rcp), op, p, sig);
    }

    // Relaying the transaction with no gas safe-bound, an attacker consumes provided gasLimit,
    // gas griefing occurs and the nonce incremented in a bad way.
    function test_PoC5_call_without_cap_gasLimit_gasGriefing() public {
        MalForwarder1 mfwd = new MalForwarder1(reg);
        MalReceiver4 mrc = new MalReceiver4();
        UserOp memory op;
        bytes memory sig;
        bytes memory data = abi.encodeCall(MalReceiver4.burnGas, ());
        op = _op(0, data);
        op.sender = attacker;
        op.to = address(mrc);
        sig = _sig(_dig(op));
        (bool ok, ) = mfwd.handleUserOp2(op, sig);
        assertTrue(ok);
    }

    function test_PoC6_tamperedCallData_Revert_RCPV2_BadDataLength() public {
        MalForwarder1 mfwd = new MalForwarder1(reg);
        registry.updateDomain(block.chainid, address(mfwd));
        UserOp memory op;
        PermitParams memory p;
        bytes memory sig;
        bytes memory data = abi.encodeCall(ReceiverMockV2.deposit, ());
        op = _op(1 ether, data);
        bytes32 dig = mfwd.digest(op);
        sig = _sig(dig);
        p = _p(0);
        vm.expectRevert(ReceiverMockV2.RCPV2_BadDataLength.selector);
        mfwd.handleUserOpWithBadData{value: 1 ether}(address(rcp), op, p, sig);
    }
}
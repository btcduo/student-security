// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { UserOp } from "../structs/UserOp.sol";
import { PermitParams } from "../structs/PermitParams.sol";
import { UserOpHash } from "../libraries/UserOpHash.sol";
import { SignatureRouter } from "../libraries/SignatureRouter.sol";
import { IDomainRegistry } from "../interfaces/IDomainRegistry.sol";
import { ISecureRecipientV2 } from "../interfaces/ISecureRecipientV2.sol";

contract MalForwarder1 {
    error Paused();
    error ZeroDomainAddr();
    error DomainAddrNotContract();
    error BadDomainId();
    error ZeroSenderAddr();
    error ZeroTargetAddr();
    error TargetNotContract();
    error BadGasLimit();
    error BadNonce();
    error ExpiredRequest();
    // error Fwd_BadSig();
    error BadMsgValue();
    error InsufficientGasToCall();

    bytes32 public constant DOMAIN_HASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 public constant NAME_HASH = keccak256(bytes("ForwarderV2"));
    bytes32 public constant VER_HASH = keccak256(bytes("2"));

    bytes4 public constant PERMIT_SEL = ISecureRecipientV2.executeWithPermit.selector;

    IDomainRegistry public reg; // 暂时只做部署绑定, 后续如有需要再加多签与reg更换接口.
    bytes32 public immutable domainId;
    bool public pause;
    mapping(address => uint256) public nonces;
    uint256 internal constant MINGAS = 50_000;
    uint256 internal constant MAXGAS = 500_000;
    uint256 internal constant BASE_GAS_OVERHEAD = 25_000;

    constructor(IDomainRegistry r) {
        if(address(r) == address(0)) {
            revert ZeroDomainAddr();
        }
        if(address(r).code.length == 0) {
            revert DomainAddrNotContract();
        }
        reg = r;
        domainId = reg.getDomainId();
        pause = false;
    }

    modifier NotPaused() {
        if(pause) {
            revert Paused();
        }
        _;
    }

    event Executed(
        address indexed sender,
        address to,
        uint256 value,
        uint256 gasLimit,
        uint256 nonce,
        uint256 deadline,
        bytes4 data
    );

    function slotOfNonce(address addr) external pure returns(bytes32) {
        bytes32 p;
        assembly {
            p := nonces.slot
        }
        return keccak256(abi.encode(addr, p));
    }

    function setPause(bool p) external {
        pause = p;
    }

    function _domainHash() internal view returns(bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_HASH,
                NAME_HASH,
                VER_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    function _digest(UserOp calldata op) internal view returns(bytes32) {
        bytes32 structHash = UserOpHash.callDataHash(op);
        return keccak256(
            abi.encodePacked(
                "\x19\x01", _domainHash(), structHash
            )
        );
    }

    function digest(UserOp calldata op) external view returns(bytes32) {
        return _digest(op);
    }

    function _validateUserOp(UserOp calldata op, bytes calldata sig) internal view returns(bool) {
        bytes32 dig = _digest(op);
        return SignatureRouter.tryRecoverOr1271(op.sender, dig, sig);
    }

    function _preValidation(
        UserOp calldata op,
        bytes calldata sig
    ) internal view {
        if(op.sender == address(0)) {
            revert ZeroSenderAddr();
        }
        if(op.to == address(0)) {
            revert ZeroTargetAddr();
        }
        if(op.to.code.length == 0) {
            revert TargetNotContract();
        }
        // if(op.gasLimit < MINGAS || op.gasLimit > MAXGAS) {
            // revert BadGasLimit();
        // }
        if(nonces[op.sender] != op.nonce) {
            revert BadNonce();
        }
        if(block.timestamp > op.deadline) {
            revert ExpiredRequest();
        }
        // if(reg.forwarderOf(domainId, block.chainid) != address(this)) {
        //     revert BadDomainId();
        // }
        // if(!_validateUserOp(op, sig)) {
        //     revert Fwd_BadSig();
        // }
    }

    function preValidation(
        UserOp calldata op,
        bytes calldata sig
    ) external view {
        _preValidation(op, sig);
    }

    function handleUserOp(
        UserOp calldata op,
        bytes calldata sig
    ) external payable NotPaused returns(bool ok, bytes memory ret) {
        _preValidation(op, sig);
        if(msg.value != op.value) {
            revert BadMsgValue();
        }
        uint256 gasStart = gasleft();
        uint256 safeGas = gasStart - (gasStart / 64) - BASE_GAS_OVERHEAD;
        if(safeGas < MINGAS) {
            revert InsufficientGasToCall();
        }
        nonces[op.sender] = nonces[op.sender] + 1;
        uint256 cap = op.gasLimit < safeGas ? op.gasLimit : safeGas;
        bytes memory callData = abi.encodePacked(op.data, op.sender);
        (ok, ret) = op.to.call{value: op.value, gas: cap}(callData);
        emit Executed(op.sender, op.to, op.value, op.gasLimit, op.nonce, op.deadline, bytes4(op.data));
    }

    function handleUserOpViaRecipientV2(
        address rcp,
        UserOp calldata op,
        PermitParams calldata p,
        bytes calldata sig
    ) external payable NotPaused returns(bool ok, bytes memory ret) {
        _preValidation(op, sig);
        if(msg.value != op.value) {
            revert BadMsgValue();
        }
        uint256 gasStart = gasleft();
        uint256 safeGas = gasStart - (gasStart / 64) - BASE_GAS_OVERHEAD;
        if(safeGas < MINGAS) {
            revert InsufficientGasToCall();
        }
        nonces[op.sender] = nonces[op.sender] + 1;
        uint256 cap = op.gasLimit < safeGas ? op.gasLimit : safeGas;
        bytes memory callData = abi.encodePacked(op.data, op.sender);
        bytes memory cd = abi.encodeWithSelector(PERMIT_SEL, op, p, callData, sig);
        (ok, ret) = rcp.call{value: op.value, gas: cap}(cd);
        if(!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function handleUserOpWithBadData(
        address rcp,
        UserOp calldata op,
        PermitParams calldata p,
        bytes calldata sig
    ) external payable NotPaused returns(bool ok, bytes memory ret) {
        _preValidation(op, sig);
        if(msg.value != op.value) {
            revert BadMsgValue();
        }
        uint256 gasStart = gasleft();
        uint256 safeGas = gasStart - (gasStart / 64) - BASE_GAS_OVERHEAD;
        if(safeGas < MINGAS) {
            revert InsufficientGasToCall();
        }
        nonces[op.sender] = nonces[op.sender] + 1;
        uint256 cap = op.gasLimit < safeGas ? op.gasLimit : safeGas;
        bytes19 badSender = bytes19(0xffffffffffffffffffffaaaaaaaaaaaaaaaaaa);
        bytes memory callData = abi.encodePacked(op.data, badSender);
        bytes memory cd = abi.encodeWithSelector(PERMIT_SEL, op, p, callData, sig);
        (ok, ret) = rcp.call{value: op.value, gas: cap}(cd);
        if(!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function handleUserOp2(
        UserOp calldata op,
        bytes calldata sig
    ) external payable NotPaused returns(bool ok, bytes memory ret) {
        _preValidation(op, sig);
        if(msg.value != op.value) {
            revert BadMsgValue();
        }
        uint256 gasStart = gasleft();
        uint256 safeGas = gasStart - (gasStart / 64) - BASE_GAS_OVERHEAD;
        // if(safeGas < MINGAS) {
            // revert InsufficientGasToCall();
        // }
        nonces[op.sender] = nonces[op.sender] + 1;
        // uint256 cap = op.gasLimit < safeGas ? op.gasLimit : safeGas;
        bytes memory callData = abi.encodePacked(op.data, op.sender);
        (ok, ret) = op.to.call{value: op.value, gas: safeGas}(callData);
        emit Executed(op.sender, op.to, op.value, op.gasLimit, op.nonce, op.deadline, bytes4(op.data));
    }

}
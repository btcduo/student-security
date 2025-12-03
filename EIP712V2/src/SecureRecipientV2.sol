// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IDomainRegistry } from "./interfaces/IDomainRegistry.sol";
import { IERC20Mock } from "./interfaces/IERC20Mock.sol";
import { IForwarderDigest } from "./interfaces/IForwarderDigest.sol";
import { SignatureRouter } from "./libraries/SignatureRouter.sol";
import { PermitParams } from "./structs/PermitParams.sol";
import { UserOp } from "./structs/UserOp.sol";

contract SecureRecipientV2 {
    error ZeroIDomainRegistry();
    error IDomainRegistryAddrNotContract();
    error NotTrustedForwarder();
    error PermitFailed();
    error SRC_BadSig();

    IDomainRegistry public immutable reg;
    bytes32 public immutable domainId;

    bytes4 public constant PERMIT_SEL = IERC20Mock.permit.selector;
    
    constructor(IDomainRegistry r) {
        if(address(r) == address(0)) {
            revert ZeroIDomainRegistry();
        }
        if(address(r).code.length == 0) {
            revert IDomainRegistryAddrNotContract();
        }
        reg = r;
        domainId = reg.getDomainId();
    }

    modifier onlyForwarded() {
        if(msg.sender != reg.forwarderOf(domainId, block.chainid)) {
            revert NotTrustedForwarder();
        }
        _;
    }

    event Permitted(address indexed token, address owner, address spender, uint256 value, uint256 deadline);
    event Executed(address indexed sender, address to, uint256 value, uint256 gasLimit, uint256 nonce, uint256 deadline);
    
    function _preValidateSig(UserOp calldata op, bytes calldata sig) internal view {
        bytes32 dig = IForwarderDigest(msg.sender).digest(op);
        bool ok = SignatureRouter.tryRecoverOr1271(op.sender, dig, sig);
        if(!ok) {
            revert SRC_BadSig();
        }
    }

    function executeWithPermit(
        UserOp calldata op,
        PermitParams calldata p,
        bytes calldata callData,
        bytes calldata sig
    ) external payable onlyForwarded returns(bool ok, bytes memory ret) {
        _preValidateSig(op, sig);
        bytes memory permitCd = 
            abi.encodeWithSelector(
                PERMIT_SEL, p.owner, p.spender, p.value, p.deadline, p.v, p.r, p.s);
        (bool ok_, ) = p.token.call(permitCd);
        if(!ok_) {
            revert PermitFailed();
        }
        emit Permitted(p.token, p.owner, p.spender, p.value, p.deadline);
        (ok, ret) = op.to.call{value: msg.value, gas: op.gasLimit}(callData);
        if(!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        emit Executed(op.sender, op.to, op.value, op.gasLimit, op.nonce, op.deadline);
    }
}
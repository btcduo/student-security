// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IDomainRegistry } from "./interfaces/IDomainRegistry.sol";

contract SecureRecipient {
    error ZeroDomainRegistryAddr();
    error TargetNotContract();
    error NotTrustedForwarder();
    error UnexpectedSender();
    error RCP_BadDataLength();
    
    IDomainRegistry immutable reg;
    bytes32 public immutable domainId;

    constructor(IDomainRegistry r) {
        if(address(r) == address(0)) {
            revert ZeroDomainRegistryAddr();
        }
        if(address(r).code.length == 0) {
            revert TargetNotContract();
        }
        reg = r;
        domainId = reg.getDomainId();
    }

    modifier onlyForwarded() {
        if(msg.sender != _trustedForwarder()) {
            revert NotTrustedForwarder();
        }
        _;
    }

    function _msgSender() internal view returns(address sender) {
        sender = msg.sender;
        if(msg.sender == _trustedForwarder()) {
            if(msg.data.length < 24) {
                revert RCP_BadDataLength();
            }
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        }
    }

    function _trustedForwarder() internal view returns(address) {
        return reg.forwarderOf(domainId, block.chainid);
    }
}
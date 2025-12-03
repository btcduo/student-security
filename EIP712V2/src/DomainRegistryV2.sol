// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract DomainRegistryV2 {
    error NotOwner();
    error ZeroChainId();
    error ZeroForwarderAddr();
    error ForwarderNotContract();
    error AlreadyRegistered();
    error RepeatedForwarderAddr();
    error NotRegistry();

    bytes32 internal constant DOMAINHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
    );
    bytes32 internal constant NAME = keccak256(bytes("DomainRegistry"));
    bytes32 internal constant VERSION = keccak256(bytes("1"));

    address public owner;
    bytes32 public immutable domainId;
    mapping(bytes32 => mapping(uint256 => address)) public forwarderOf;

    constructor() {
        owner = msg.sender;
        domainId = _generateDomainId();
    }
    
    modifier onlyOwner() {
        if(msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    event DomainRegistered(bytes32 indexed domainId, uint256 chainId, address forwarder);
    event DomainUpdated(bytes32 indexed domainId, address oldForwarder, address newForwarder);

    function getDomainId() external view returns(bytes32) {
        return domainId;
    }

    function registerDomain(uint256 chainId, address forwarder) external onlyOwner {
        _checkZeroParams(chainId, forwarder);
        if(forwarderOf[domainId][chainId] != address(0)) {
            revert AlreadyRegistered();
        }
        forwarderOf[domainId][chainId] = forwarder;
        emit DomainRegistered(domainId, chainId, forwarder);
    }

    function updateDomain(uint256 chainId, address newForwarder) external onlyOwner {
        _checkZeroParams(chainId, newForwarder);
        if(forwarderOf[domainId][chainId] == newForwarder) {
            revert RepeatedForwarderAddr();
        }
        if(forwarderOf[domainId][chainId] == address(0)) {
            revert NotRegistry();
        }
        address oldForwarder = forwarderOf[domainId][chainId];
        forwarderOf[domainId][chainId] = newForwarder;
        emit DomainUpdated(domainId, oldForwarder, newForwarder);
    }

    function _checkZeroParams(uint256 chainId, address addr) internal view {
        if(chainId == 0) {
            revert ZeroChainId();
        }
        if(addr == address(0)) {
            revert ZeroForwarderAddr();
        }
        if(addr.code.length == 0) {
            revert ForwarderNotContract();
        }
    }

    function _generateDomainId() internal view returns(bytes32) {
        return keccak256(
            abi.encode(
                DOMAINHASH,
                NAME,
                VERSION,
                block.chainid,
                address(this)
            )
        );
    }
}
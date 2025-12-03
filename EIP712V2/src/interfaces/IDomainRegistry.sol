// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IDomainRegistry {
    function getDomainId() external view returns(bytes32);

    function forwarderOf(bytes32 domainId, uint256 chainId) external view returns(address);
}
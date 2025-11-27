// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MultiSig {
    error ZeroAddr();
    error NotOwner();
    error NotSelf();
    error UnsafeParams();
    error RepeatedParams();
    error InvalidOwnerIndex();
    error AlreadyApproved();
    error AlreadyExecuted();
    error UnApprovedRequest();
    error CallFailed();

    struct Tx {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }
    Tx[] public txs;

    mapping(address => bool) public owners;
    address[] public ownerList;
    mapping(address => uint256) public ownerIndex;
    mapping(uint256 => mapping(address => bool)) public approved;
    uint256 public threshold;

    constructor(address a, address b) {
        if(a == address(0) || b == address(0)) {
            revert ZeroAddr();
        }
        owners[a] = true;
        ownerList.push(a);
        ownerIndex[a] = ownerList.length; // i + 1.
        owners[b] = true;
        ownerList.push(b);
        ownerIndex[b] = ownerList.length;
        threshold = 2;
    }

    modifier onlyOwner() {
        if(!owners[msg.sender]) {
            revert NotOwner();
        }
        _;
    }

    modifier onlySelf() {
        if(msg.sender != address(this)) {
            revert NotSelf();
        }
        _;
    }

    event Submitted(address indexed who, uint256 txId, address to, uint256 amount, bytes data);
    event Confirmed(address indexed who, uint256 txId, uint256 count, uint256 need);
    event Executed(address indexed who, uint256 txId, address to, bool isExecuted);
    event OwnerAdded(address indexed who, uint256 ownerIdx, bool isOwner);
    event OwnerRemoved(address indexed who, bool isOwner, uint256 ownerIdx);
    event ThresholdModified(uint256 oldThreshold, uint256 newThreshold);

    /// @notice explicit entry for onlyOwner.
    function submit(address t, uint256 v, bytes calldata d) external onlyOwner returns(uint256 txId) {
        txId = _submit(t, v, d);
    }

    function confirm(uint256 txId) external onlyOwner {
        _confirm(txId);
    }

    function execute(uint256 txId) external onlyOwner {
        _execute(txId);
    }

    /// @notice Propose critical-governance for onlyOwner.
    function proposeAddOwner(address addr) external onlyOwner returns(uint256 txId) {
        if(addr == address(0)) {
            revert ZeroAddr();
        }
        if(owners[addr]) {
            revert RepeatedParams();
        }
        if(ownerIndex[addr] != 0) {
            revert InvalidOwnerIndex();
        }
        bytes memory d = abi.encodeCall(this.addOwner, (addr));
        txId = _submit(address(this), 0, d);
    }

    function proposeRemoveOwner(address addr) external onlyOwner returns(uint256 txId) {
        if(addr == address(0)) {
            revert ZeroAddr();
        }
        if(ownerList.length <= threshold) {
            revert UnsafeParams();
        }
        if(!owners[addr]) {
            revert NotOwner();
        }
        if(ownerIndex[addr] == 0) {
            revert InvalidOwnerIndex();
        }
        bytes memory d = abi.encodeCall(this.removeOwner, (addr));
        txId = _submit(address(this), 0, d);
    }

    function proposeModifyThreshold(uint256 newThresh) external onlyOwner returns(uint256 txId) {
        if(newThresh > ownerList.length) {
            revert UnsafeParams();
        }
        if(newThresh == threshold) {
            revert RepeatedParams();
        }
        bytes memory d = abi.encodeCall(this.modifyThreshold, (newThresh));
        txId = _submit(address(this), 0, d);
    }

    /// @notice Modify storage slots for onlySelf.
    function addOwner(address addr) external onlySelf {
        _addOwner(addr);
    }

    function removeOwner(address addr) external onlySelf {
        _removeOwner(addr);
    }
    
    function modifyThreshold(uint256 newThresh) external onlySelf {
        _modifyThreshold(newThresh);
    }

    /// @dev Core logic for mutating storage slot.
    function _addOwner(address addr) internal {
        if(addr == address(0)) {
            revert ZeroAddr();
        }
        if(owners[addr]) {
            revert RepeatedParams();
        }
        if(ownerIndex[addr] != 0) {
            revert InvalidOwnerIndex();
        }
        owners[addr] = true;
        ownerList.push(addr);
        ownerIndex[addr] = ownerList.length;
        uint256 ownerIdx = ownerIndex[addr] - 1;
        emit OwnerAdded(addr, ownerIdx, owners[addr]);
    }

    function _removeOwner(address addr) internal {
        if(addr == address(0)) {
            revert ZeroAddr();
        }
        if(ownerList.length <= threshold) {
            revert UnsafeParams();
        }
        if(!owners[addr]) {
            revert NotOwner();
        }
        if(ownerIndex[addr] == 0) {
            revert InvalidOwnerIndex();
        }
        uint256 ownerIdx = ownerIndex[addr] - 1;
        uint256 lastIdx = ownerList.length - 1;
        if(ownerIdx != lastIdx) {
            address lastOwner = ownerList[lastIdx];
            ownerList[ownerIdx] = lastOwner;
            ownerIndex[lastOwner] = ownerIdx + 1;
        }
        ownerList.pop();
        owners[addr] = false;
        ownerIndex[addr] = 0;
        emit OwnerRemoved(addr, owners[addr], ownerIndex[addr]);
    }

    function _modifyThreshold(uint256 newThresh) internal {
        if(newThresh < 2 || newThresh > ownerList.length) {
            revert UnsafeParams();
        }
        if(newThresh == threshold) {
            revert RepeatedParams();
        }
        uint256 oldThresh = threshold;
        threshold = newThresh;
        emit ThresholdModified(oldThresh, newThresh);
    }

    /// @dev Implicit entry points for execution.
    function _submit(address t, uint256 v, bytes memory d) internal returns(uint256 txId) {
        if(t == address(0)) {
            revert ZeroAddr();
        }
        txs.push(Tx({to: t, value: v, data: d, executed: false}));
        txId = txs.length - 1;
        emit Submitted(msg.sender, txId, t, v, d);
    }

    function _confirm(uint256 txId) internal {
        if(approved[txId][msg.sender]) {
            revert AlreadyApproved();
        }
        if(txs[txId].executed) {
            revert AlreadyExecuted();
        }
        approved[txId][msg.sender] = true;
        uint256 count = _applyConfirmedCount(txId);
        emit Confirmed(msg.sender, txId, count, threshold);
    }

    function _execute(uint256 txId) internal {
        if(_applyConfirmedCount(txId) < threshold) {
            revert UnApprovedRequest();
        }
        if(txs[txId].executed) {
            revert AlreadyExecuted();
        }
        Tx storage t = txs[txId];
        t.executed = true;
        (bool ok, ) = t.to.call{value: t.value}(t.data);
        if(!ok) {
            revert CallFailed();
        }
        emit Executed(msg.sender, txId, t.to, t.executed);
    }

    function _applyConfirmedCount(uint256 txId) internal view returns(uint256 count) {
        uint256 totalCount;
        for(uint256 i; i < ownerList.length; i++) {
            if(approved[txId][ownerList[i]]) {
                totalCount++;
            }
        }
        count = totalCount;
    }

    function getOwnerLength() external view returns(uint256) {
        return ownerList.length;
    }
}
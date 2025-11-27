// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MinimalMultisigV2_Rewrite {
    error ZeroThreshold();
    error NotOwner();
    error OnlySelf();
    error ZeroOwnerAddrSet();
    error OwnerOccupied();
    error ZeroAddr();
    error UnsafeParams();
    error ThresholdRepeated();
    error AlreadyApproved();
    error AlreadyExecuted();
    // error InsufficientValue();
    error TransferFailed();

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

    constructor(uint256 t) {
        if(t == 0) {
            revert ZeroThreshold();
        }
        threshold = t;
        owners[msg.sender] = true;
        ownerList.push(msg.sender);
        ownerIndex[msg.sender] = ownerList.length;
    }

    modifier onlyOwner() {
        if(!owners[msg.sender]) {
            revert NotOwner();
        }
        _;
    }

    modifier onlySelf() {
        if(msg.sender != address(this)) {
            revert OnlySelf();
        }
        _;
    }

    event OwnerRemoved(uint256 oldOwnerIdx, bool stillOwner);
    event ThresholdModified(uint256 oldThreshold, uint256 newThreshold);
    event Submitted(address indexed submitter, address to, uint256 value, bytes data);
    event Confirmed(address indexed confirmer, uint256 txId, uint256 approvedCount, uint256 needCount);
    event Executed(address indexed executor, uint256 txId, bool isExecuted);

    /// @notice Add new owner via multisig governance.
    function proposeAddOwner(address addr) external onlyOwner returns(uint256 id) {
        if(addr == address(0)) {
            revert ZeroOwnerAddrSet();
        }
        if(owners[addr]) {
            revert OwnerOccupied();
        }
        bytes memory data = abi.encodeCall(this.setOwner, (addr));
        id = _submit(address(this), 0, data);
    }
    /// @notice Remove per owner via multisig.
    function proposeRemoveOwner(address addr) external onlyOwner returns(uint256 id) {
        if(addr == address(0)) {
            revert ZeroAddr();
        }
        if(ownerIndex[addr] == 0) {
            revert NotOwner();
        }
        if(ownerList.length <= threshold) {
            revert UnsafeParams();
        }
        bytes memory data = abi.encodeCall(this.removeOwner, (addr));
        id = _submit(address(this), 0, data);
    }
    /// @notice Modify threshold via multisig.
    function proposeModifyThreshold(uint256 newThreshold) external onlyOwner returns(uint256 id) {
        if(newThreshold == 0 || newThreshold > ownerList.length) {
            revert UnsafeParams();
        }
        if(newThreshold == threshold) {
            revert ThresholdRepeated();
        }
        bytes memory data = abi.encodeCall(this.modifyThreshold, (newThreshold));
        id = _submit(address(this), 0, data);
    }

    /// @notice Helper only for proposeAddOwner()
    function setOwner(address addr) external onlySelf {
        _setOwnerInternal(addr);
    }

    /// @dev Core function for adding a new owner.
    function _setOwnerInternal(address addr) internal {
        if(addr == address(0)) {
            revert ZeroOwnerAddrSet();
        }
        if(owners[addr]) {
            revert OwnerOccupied();
        }
        owners[addr] = true;
        ownerList.push(addr);
        ownerIndex[addr] = ownerList.length; // i+1;
    }

    /// @notice Helper only for proposeRemoveOwner()
    function removeOwner(address addr) external onlySelf {
        _removeOwnerInternal(addr);
    }

    /// @dev Core function for removing a existed owner.
    function _removeOwnerInternal(address addr) internal {
        if(addr == address(0)) {
            revert ZeroAddr();
        }
        if(ownerList.length <= threshold) {
            revert UnsafeParams();
        }
        uint256 idxPlusOne = ownerIndex[addr];
        if(idxPlusOne == 0) {
            revert NotOwner();
        }
        uint256 idx = idxPlusOne - 1;
        uint256 lastIdx = ownerList.length - 1;
        if(idx != lastIdx) {
            address lastOwner = ownerList[lastIdx];
            ownerList[idx] = lastOwner;
            ownerIndex[lastOwner] = idx + 1;
        }
        ownerList.pop();
        owners[addr] = false;
        ownerIndex[addr] = 0;
        emit OwnerRemoved(ownerIndex[addr], owners[addr]);
    }

    /// @notice Helper only for _modifyThresholdInternal().
    function modifyThreshold(uint256 newThresh) external onlySelf {
        _modifyThresholdInternal(newThresh);
    }

    /// @dev Core function of modify threshold.
    function _modifyThresholdInternal(uint256 newThresh) internal {
        if(newThresh == 0 || newThresh > ownerList.length) {
            revert UnsafeParams();
        }
        if(newThresh == threshold) {
            revert ThresholdRepeated();
        }
        uint256 oldThresh = threshold;
        threshold = newThresh;
        emit ThresholdModified(oldThresh, newThresh);
    }

    function submit(address t, uint256 v, bytes memory d) external onlyOwner returns(uint256) {
        return _submit(t, v, d);
    }
    
    function _submit(address t,uint256 v,bytes memory d) internal returns(uint256 txId) {
        txs.push(Tx({to: t, value: v, data: d, executed: false}));
        txId = txs.length - 1;
        emit Submitted(msg.sender, t, v, d);
    }

    function confirm(uint256 txId) external onlyOwner {
        if(approved[txId][msg.sender]) {
            revert AlreadyApproved();
        }
        if(txs[txId].executed) {
            revert AlreadyExecuted();
        }
        approved[txId][msg.sender] = true;
        uint256 count;
        for(uint256 i; i < ownerList.length; i++) {
            if(approved[txId][ownerList[i]]) {
                count++;
            }
        }
        emit Confirmed(msg.sender, txId, count, threshold);
        if(count >= threshold) {
            _execute(txId);
        }
    }

    function _execute(uint256 txId) internal {
        Tx storage t = txs[txId];
        t.executed = true;
        (bool ok, ) = t.to.call{value: t.value}(t.data);
        if(!ok) {
            revert TransferFailed();
        }
        emit Executed(msg.sender, txId, t.executed);
    }

    function txState(uint256 txId) external view returns(
        address,
        uint256,
        bytes memory,
        bool
    ) {
        Tx storage t = txs[txId];
        return (t.to, t.value, t.data, t.executed);
    }

    function ownerListLength() external view returns(uint256) {
        return ownerList.length;
    }
}
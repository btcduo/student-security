// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MinimalMultisigV2 {
    error ZeroThreshold();
    error NotOwner();
    error ZeroOwnerAddrSet();
    error OwnerOccupied();
    error AlreadyApproved();
    error AlreadyExecuted();
    error InsufficientValue();
    error TransferFailed();

    struct Tx {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }
    Tx[] public txs;

    uint256 public threshold;
    mapping(address => bool) public owners;
    address[] public ownerList;
    mapping(uint256 => mapping(address => bool)) public approved;

    event OwnerSet(address indexed sender, address newOwner);
    event Submitted(address indexed sender, address to, uint256 value, uint256 txId);
    event Confirmed(address indexed sender, uint256 txId, uint256 approvedCount);
    event Executed(address indexed sender, uint256 txId, bool isExecuted);

    constructor(uint256 t) {
        if(t == 0) {
            revert ZeroThreshold();
        }
        owners[msg.sender] = true;
        ownerList.push(msg.sender);
        threshold = t;
    }

    modifier onlyOwner() {
        if(!owners[msg.sender]) {
            revert NotOwner();
        }
        _;
    }

    function setOwner(address addr) external onlyOwner {
        if(addr == address(0)) {
            revert ZeroOwnerAddrSet();
        }
        if(owners[addr]) {
            revert OwnerOccupied();
        }
        owners[addr] = true;
        ownerList.push(addr);
        emit OwnerSet(msg.sender, addr);
    }

    function submit(
        address to_,
        uint256 value_,
        bytes memory data_
    ) external onlyOwner returns(uint256 txId) {
        txs.push(Tx({to: to_, value: value_, data: data_, executed: false}));
        txId = txs.length - 1;
        emit Submitted(msg.sender, to_, value_, txId);
    }

    function confirm(uint256 txId) external payable onlyOwner {
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
        emit Confirmed(msg.sender, txId, count);
        if(count >= threshold) {
            if(txs[txId].value > msg.value) {
                revert InsufficientValue();
            }
            _execute(txId);
        }
    }

    function _execute(uint256 id) internal {
        Tx storage tx_ = txs[id];
        (bool ok, ) = tx_.to.call{value: tx_.value}(tx_.data);
        if(!ok) {
            revert TransferFailed();
        }
        tx_.executed = true;
        emit Executed(msg.sender, id, tx_.executed);
    }

    function txState(uint256 txId) external view returns(
        address to,
        uint256 value,
        bytes memory data,
        bool executed
    ) {
        Tx storage t = txs[txId];
        return (t.to, t.value, t.data, t.executed);
    }
}
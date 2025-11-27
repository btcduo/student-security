// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MinimalMultisig {
    error NotOwner();
    error AlreadyConfirmed();
    error AlreadyExecuted();
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
    uint256 public threshold;
    mapping(uint256 => mapping(address => bool)) public approved;

    constructor(uint256 t) {
        threshold = t;
    }

    modifier onlyOwner() {
        if(!owners[msg.sender]) {
            revert NotOwner();
        }
        _;
    }

    function setOwner(address a1, address a2, address a3) external {
        owners[a1] = true;
        owners[a2] = true;
        owners[a3] = true;
        ownerList.push(a1);
        ownerList.push(a2);
        ownerList.push(a3);
    }

    function submit(
        address to_, 
        uint256 value_, 
        bytes calldata data_
    ) external onlyOwner returns(uint256 txId) {
        Tx memory tx_ = Tx({to: to_, value: value_, data: data_, executed: false});
        txs.push(tx_);
        txId = txs.length - 1;
    }

    function confirm(uint256 txId) external payable onlyOwner {
        if(approved[txId][msg.sender]) {
            revert AlreadyConfirmed();
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
        if(count >= threshold) {
            _execute(txId);
        }
    }

    function execute(uint256 txId) external onlyOwner {
        _execute(txId);
    }

    function _execute(uint256 txId) internal {
        Tx storage tx_ = txs[txId];
        if(tx_.executed) {
            revert AlreadyExecuted();
        }
        (bool ok, ) = tx_.to.call{value: tx_.value}(tx_.data);
        if(!ok) {
            revert TransferFailed();
        }
        tx_.executed = true;
    }

    function txState(uint256 id) external view returns(bool) {
        return txs[id].executed;
    }
}
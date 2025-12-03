// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { SecureRecipient } from "../SecureRecipient.sol";
import { IERC20Mock } from "../interfaces/IERC20Mock.sol";
import { IDomainRegistry } from "../interfaces/IDomainRegistry.sol";
import { PermitParams } from "../structs/PermitParams.sol";

contract ReceiverMock is SecureRecipient {
    error BadValueDeposit();
    error InsufficientToWithdraw();
    error WithdrawFailed();

    bytes4 public constant TOKEN_TRANSFER_SEL = IERC20Mock.transferFrom.selector;
    bytes4 public constant TOKEN_PERMIT_SEL = IERC20Mock.permit.selector;

    uint256 public sum;
    mapping(address => uint256) public balanceOf;

    constructor(IDomainRegistry r) SecureRecipient(r) {}

    event Deposit(address indexed caller, address sender, uint256 amount);
    event Withdrawn(address indexed caller, address sender, uint256 amount);

    function deposit() external payable onlyForwarded {
        if(msg.value == 0) {
            revert BadValueDeposit();
        }
        address realSender = _msgSender();
        balanceOf[realSender] += msg.value;
        emit Deposit(msg.sender, realSender, msg.value);
    }

    function withdraw(uint256 amount) external onlyForwarded {
        address realSender = _msgSender();
        if(balanceOf[realSender] < amount) {
            revert InsufficientToWithdraw();
        }
        balanceOf[realSender] -= amount;
        (bool ok, ) = realSender.call{value: amount}("");
        if(!ok) {
            revert WithdrawFailed();
        }
        emit Withdrawn(msg.sender, realSender, amount);
    }

    function transferFrom(
        address token, 
        address from,
        address to,
        uint256 amount
    ) external onlyForwarded returns(bool ok, bytes memory ret) {
        bytes memory cd = abi.encodeWithSelector(TOKEN_TRANSFER_SEL, from, to, amount);
        (ok, ret) = token.call(cd);
        if(!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function foo() external onlyForwarded {
        sum += 1;
    }
}
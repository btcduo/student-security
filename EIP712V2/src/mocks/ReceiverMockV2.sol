// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20Mock } from "../interfaces/IERC20Mock.sol";

contract ReceiverMockV2 {
    error BadValueDeposit();
    error InsufficientToWithdraw();
    error WithdrawFailed();
    error ZeroRecipientV2Addr();
    error AddrNotContract();
    error RCPV2_BadDataLength();
    error NotRcpV2();
    error TransferTokenFailed();
    error ZeroAddr();

    bytes4 public constant TOKEN_SEL = IERC20Mock.transferFrom.selector;

    address public immutable rcpV2;
    uint256 public sum;
    mapping(address => uint256) public balanceOf;

    constructor(address r) {
        if(r == address(0)) {
            revert ZeroRecipientV2Addr();
        }
        if(r.code.length == 0) {
            revert AddrNotContract();
        }
        rcpV2 = r;
    }

    modifier onlyRcpV2() {
        if(msg.sender != rcpV2) {
            revert NotRcpV2();
        }
        _;
    }

    event Deposit(address indexed caller, address sender, uint256 amount);
    event Withdrawn(address indexed caller, address sender, uint256 amount);

    function _msgSender() internal view returns(address sender) {
        sender = msg.sender;
        if(msg.sender == rcpV2) {
            if(msg.data.length < 24) {
                revert RCPV2_BadDataLength();
            }
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        }
    }

    function deposit() external payable onlyRcpV2 {
        if(msg.value == 0) {
            revert BadValueDeposit();
        }
        address realSender = _msgSender();
        balanceOf[realSender] += msg.value;
        emit Deposit(msg.sender, realSender, msg.value);
    }

    function withdraw(uint256 amount) external onlyRcpV2 {
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
    ) external onlyRcpV2 returns(bool ok, bytes memory ret) {
        if(token.code.length == 0) {
            revert AddrNotContract();
        }
        if(from == address(0) || to == address(0)) {
            revert ZeroAddr();
        }
        bytes memory cd = abi.encodeWithSelector(TOKEN_SEL, from, to, amount);
        (ok, ret) = token.call(cd);
        if(!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function foo() external {
        sum += 1;
    }
}
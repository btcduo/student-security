// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract USDTMock is ERC20 {
    constructor() ERC20("USDT MOCK", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address account, uint256 value) external {
        _burn(account, value);
    }
}
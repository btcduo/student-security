// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IAMMPair {
    function getReserves() external view returns(uint256 reserve0, uint256 reserve1);
}

contract SpotOracle_Rewrite {
    /// @notice The address of AMMPair_Rewrite
    IAMMPair public immutable pair;

    /// @notice Last update timestamp.
    uint256 public lastUpdateAt;

    /// @notice Last recorded price of token0 in terms of token1.
    uint256 public lastPrice0;
    
    /// @notice last recorded price of token1 in terms of token0.
    uint256 public lastPrice1;

    error ZeroAddress();
    error InvalidAddress();
    error NoLiquidity();
    error PriceNotInitialized();

    event Updated(address indexed caller, uint256 price0, uint256 price1, uint256 updateTime);

    constructor(address _pair) {
        if(_pair == address(0)) {
            revert ZeroAddress();
        }
        if(_pair.code.length == 0) {
            revert InvalidAddress();
        }
        pair = IAMMPair(_pair);
    }

    function _computeSpotPrice(
        uint256 reserve0,
        uint256 reserve1
    ) private pure returns(uint256 price0, uint256 price1) {
        price0 = reserve1 * 1e18 / reserve0;
        price1 = reserve0 * 1e18 / reserve1;
    }

    function update() external returns(uint256 price0, uint256 price1) {
        (uint256 reserve0, uint256 reserve1) = pair.getReserves();
        if(reserve0 == 0 || reserve1 == 0) {
            revert NoLiquidity();
        }
        (price0, price1) = _computeSpotPrice(reserve0, reserve1);

        lastUpdateAt = block.timestamp;
        lastPrice0 = price0;
        lastPrice1 = price1;

        emit Updated(msg.sender, price0, price1, block.timestamp);
   }

   function getPrice0() external view returns(uint256) {
        if(lastUpdateAt == 0) {
            revert PriceNotInitialized();
        }
        return lastPrice0;
   }

   function getPrice1() external view returns(uint256) {
        if(lastUpdateAt == 0) {
            revert PriceNotInitialized();
        }
        return lastPrice1;
   }
}
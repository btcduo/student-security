// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Minimal interface to read reserves from the AMM pair.
interface IAMMPair {
    function getReserves() external view returns(uint256 _reserve0, uint256 _reserve1);
}

/// @notice Naive spot price oracle that reads price from a single AMM pair.
/// It stores the last updated spot price and returns it to consumers.
contract SpotOracle {
    address public immutable pair;
    uint8 public constant DECIMALS = 18; // price is scaled by 1e18

    /// @notice Timestapm of the last successful update.
    uint256 public lastUpdateAt;

    /// @notice Last recorded price of token0 in terms of token1, scaled by 1e18.
    uint256 public lastPrice0;

    /// @notice Last recorded price of token1 in terms of token0, scaled by 1e18.
    uint256 public lastPrice1;

    error ZeroAddress();
    error InvalidAddress();
    error NoLiquidity();
    error PriceNotInitialized();

    event PriceUpdated(uint256 price0, uint256 price1, uint256 timestamp);

    constructor(address _pair) {
        if(_pair == address(0)) {
            revert ZeroAddress();
        }
        if(_pair.code.length == 0) {
            revert InvalidAddress();
        }
        pair = _pair;
    }

    /// @dev Compute spot prices from AMM reserves:
    /// price0 = reserve1 / reserve0 (token0 priced of token1)
    /// price1 = reserve0 / reserve1 (token1 priced of token0)
    function _computeSpotPrice(
        uint256 reserve0,
        uint256 reserve1
    ) private pure returns(uint256 price0, uint256 price1) {
        // Scale by 1e18 to keep decimals
        price0 = reserve1 * 1e18 / reserve0;
        price1 = reserve0 * 1e18 / reserve1;
    }

    /// @notice Pull the lastest reserves from the AMM and store the spot price snapshot.
    /// Anyone call call this; in practice it's usually a keeper or some off-chain bot.
    function update() external returns(uint256 price0, uint256 price1) {
        (uint256 reserve0, uint256 reserve1) = IAMMPair(pair).getReserves();
        if(reserve0 == 0 || reserve1 == 0) {
            revert NoLiquidity();
        }

        (price0, price1) = _computeSpotPrice(reserve0, reserve1);

        lastUpdateAt = block.timestamp;
        lastPrice0 = price0;
        lastPrice1 = price1;

        emit PriceUpdated(price0, price1, lastUpdateAt);
    }

    /// @notice Return the last recorded price of thken0 in terms of token1.
    /// IMPORTANT: this is the last stored price, not recomputed from current reserves.
    function getSpotPrice0() external view returns(uint256) {
        if(lastUpdateAt == 0) {
            revert PriceNotInitialized();
        }
        return lastPrice0;
    }

    /// @notice Return the last recorded price of token1 in terms of token0.
    function getSpotPrice1() external view returns(uint256) {
        if(lastUpdateAt == 0) {
            revert PriceNotInitialized();
        }
        return lastPrice1;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IAMMPair {
    function getReserves() external view returns(uint256 reserve0, uint256 reserve1);
}

contract TwapOracle_Rewrite {
    IAMMPair public immutable pair;

    /// @notice Scaled with 1e18.
    uint256 private constant DECIMAL = 1e18;

    uint256 public lastUpdateAt;
    /// @notice Last recorded price of token0 in terms of token1.
    uint256 public lastSpotPrice0;
    /// @notice Last recorded price of token1 in terms of token0.
    uint256 public lastSpotPrice1;

    uint256 public price0Cumulative;
    uint256 public price1Cumulative;

    error ZeroPair();
    error InvalidPair();
    error NoLiquidity();
    error NotInitialized();

    event TwapUpdated(
        address indexed executor,
        uint256 spotPrice0,
        uint256 spotPrice1,
        uint256 cumulative0,
        uint256 cumulative1,
        uint256 currentTime
    );

    constructor(address _pair) {
        if(_pair == address(0)) {
            revert ZeroPair();
        }
        if(_pair.code.length == 0) {
            revert InvalidPair();
        }
        pair = IAMMPair(_pair);
    }

    /// @notice Token0 priced in token1;
    /// @notice Token1 priced in token0;
    function _computePrices(
        uint256 reserve0,
        uint256 reserve1
    ) private pure returns(uint256 price0, uint256 price1) {
        price0 = reserve1 * DECIMAL / reserve0;
        price1 = reserve0 * DECIMAL / reserve1;
    }

    /// @notice Everyone can update the cumulation of token0/1.
    function update() external returns(uint256 price0, uint256 price1) {
        (uint256 reserve0, uint256 reserve1) = pair.getReserves();
        if(reserve0 == 0 || reserve1 == 0) {
            revert NoLiquidity();
        }

        uint256 currentTime = block.timestamp;
        if(lastUpdateAt != 0) {
            uint256 timeElapsed = currentTime - lastUpdateAt;
            if(timeElapsed > 0) {
                price0Cumulative += lastSpotPrice0 * timeElapsed;
                price1Cumulative += lastSpotPrice1 * timeElapsed;
            }
        }

        (price0, price1) = _computePrices(reserve0, reserve1);

        lastUpdateAt = currentTime;
        lastSpotPrice0 = price0;
        lastSpotPrice1 = price1;

        emit TwapUpdated(msg.sender, price0, price1, price0Cumulative, price1Cumulative, currentTime);
    }

    function getCurrentCumulative()
        external
        view
        returns(uint256 cumulative0, uint256 cumulative1, uint256 timestamp)
    {
        if(lastUpdateAt == 0) {
            revert NotInitialized();
        }

        timestamp = block.timestamp;
        cumulative0 = price0Cumulative;
        cumulative1 = price1Cumulative;

        uint256 timeElapsed = timestamp - lastUpdateAt;
        if(timeElapsed > 0) {
            cumulative0 += lastSpotPrice0 * timeElapsed;
            cumulative1 += lastSpotPrice1 * timeElapsed;
        }
    }
}
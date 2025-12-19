// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function balanceOf(address account) external view returns(uint256);
    function transferFrom(address from, address to, uint256 amount) external returns(bool);
    function transfer(address to, uint256 amount) external returns(bool);
}

contract AMMPair_Rewrite {
    error Zero_Token_Address();
    error Invalid_Token_Address();
    error Repeated_Token_Address();
    error Reserved_Token_OutOfBounds();
    error Insufficient_Reserved_Token();
    error Zero_Addr();
    error Zero_Liquidity();
    error Insufficient_Liquidity();
    error Zero_Amount();
    error Slippage();
    error AddLiq_Transfer_Token0_Failed();
    error AddLiq_Transfer_Token1_Failed();
    error RemoveLiq_Transfer_Token0_Failed();
    error RemoveLiq_Transfer_Token1_Failed();
    error Swap_TokenIn_Transfer_Failed();
    error Swap_TokenOut_Transfer_Failed();

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint112 public reserve0;
    uint112 public reserve1;
    
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 private constant FEE_NUMERATOR = 997;
    uint256 private constant FEE_DENOMINATOR = 1000;

    event Mint(address indexed funder, address indexed to, uint256 liquidity);
    event Burn(address indexed funder, address indexed to, uint256 liquidity);
    event Swap(
        address indexed funder,
        address indexed to,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address _token0, address _token1) {
        if(_token0 == address(0) || _token1 == address(0)) {
            revert Zero_Token_Address();
        }
        if(_token0.code.length == 0 || _token1.code.length == 0) {
            revert Invalid_Token_Address();
        }
        if(_token0 == _token1) {
            revert Repeated_Token_Address();
        }
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function getReserves() public view returns(uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = uint256(reserve0);
        _reserve1 = uint256(reserve1);
    }

    function _update(uint256 balance0, uint256 balance1) private {
        if(balance0 > type(uint112).max || balance1 > type(uint112).max) {
            revert Reserved_Token_OutOfBounds();
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    function _getAmountOut(
        uint256 amountInWithFee,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) private pure returns(uint256 amountOut) {
        if(_reserveIn == 0 || _reserveOut == 0) {
            revert Insufficient_Reserved_Token();
        }

        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = _reserveIn + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _mint(address to, uint256 liquidity) private {
        if(to == address(0)) {
            revert Zero_Addr();
        }
        if(liquidity == 0) {
            revert Zero_Liquidity();
        }

        totalSupply += liquidity;
        balanceOf[to] += liquidity;
    }

    function _burn(address from, uint256 liquidity) private {
        if(from == address(0)) {
            revert Zero_Addr();
        }
        if(liquidity == 0) {
            revert Zero_Liquidity();
        }
        if(liquidity > balanceOf[from]) {
            revert Insufficient_Liquidity();
        }

        balanceOf[from] -= liquidity;
        totalSupply -= liquidity;
    }

    function _min(uint256 a, uint256 b) private pure returns(uint256 c) {
        c = a < b ? a : b;
    }

    function _sqrt(uint256 y) private pure returns(uint256 z) {
        if(y == 0) {
            return 0;
        }
        uint256 x = y / 2 + 1;
        z = y;
        while(x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }

    function sqrt(uint256 y) external pure returns(uint256) {
        return _sqrt(y);
    }

    function addLiquidity(
        uint256 token0Desired,
        uint256 token1Desired,
        address to
    ) external returns(uint256 liquidity) {
        if(token0Desired == 0 || token1Desired == 0) {
            revert Zero_Amount();
        }
        if(to == address(0)) {
            revert Zero_Addr();
        }

        bool t0 = token0.transferFrom(msg.sender, address(this), token0Desired);
        bool t1 = token1.transferFrom(msg.sender, address(this), token1Desired);
        if(!t0) {
            revert AddLiq_Transfer_Token0_Failed();
        }
        if(!t1) {
            revert AddLiq_Transfer_Token1_Failed();
        }

        (uint256 _reserve0, uint256 _reserve1) = getReserves();

        if(totalSupply == 0) {
            liquidity = _sqrt(token0Desired * token1Desired);
        } else {
            uint256 liquidity0 = token0Desired * totalSupply / _reserve0;
            uint256 liquidity1 = token1Desired * totalSupply / _reserve1;
            liquidity = _min(liquidity0, liquidity1);
        }

        _mint(to, liquidity);

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        _update(balance0, balance1);

        emit Mint(msg.sender, to, liquidity);
    }

    function removeLiquidity(
        uint256 liquidity,
        address to
    ) external {
        if(liquidity == 0) {
            revert Zero_Liquidity();
        }
        if(liquidity > balanceOf[msg.sender]) {
            revert Insufficient_Liquidity();
        }
        if(to == address(0)) {
            revert Zero_Addr();
        }

        (uint256 _reserve0, uint256 _reserve1) = getReserves();

        uint256 amount0 = liquidity * _reserve0 / totalSupply;
        uint256 amount1 = liquidity * _reserve1 / totalSupply;

        _burn(msg.sender, liquidity);

        bool t0 = token0.transfer(to, amount0);
        bool t1 = token1.transfer(to, amount1);
        if(!t0) {
            revert RemoveLiq_Transfer_Token0_Failed();
        }
        if(!t1) {
            revert RemoveLiq_Transfer_Token1_Failed();
        }

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        _update(balance0, balance1);

        emit Burn(msg.sender, to, liquidity);
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external returns(uint256 amountOut) {
        if(tokenIn != address(token0) && tokenIn != address(token1)) {
            revert Invalid_Token_Address();
        }
        if(amountIn == 0) {
            revert Zero_Amount();
        }
        if(to == address(0)) {
            revert Zero_Addr();
        }

        bool tIn = IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        if(!tIn) {
            revert Swap_TokenIn_Transfer_Failed();
        }

        bool isToken0 = (tokenIn == address(token0));

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR / FEE_DENOMINATOR;

        (uint256 _reserve0, uint256 _reserve1) = getReserves();

        bool tOut;
        if(isToken0) {
            amountOut = _getAmountOut(amountInWithFee, _reserve0, _reserve1);
            if(amountOut < minAmountOut) {
                revert Slippage();
            }
            tOut = token1.transfer(to, amountOut);
            if(!tOut) {
                revert Swap_TokenOut_Transfer_Failed();
            }
        } else {
            amountOut = _getAmountOut(amountInWithFee, _reserve1, _reserve0);
            if(amountOut < minAmountOut) {
                revert Slippage();
            }
            tOut = token0.transfer(to, amountOut);
            if(!tOut) {
                revert Swap_TokenOut_Transfer_Failed();
            }
        }

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        _update(balance0, balance1);

        emit Swap(msg.sender, to, tokenIn, amountIn, amountOut);
    }
}
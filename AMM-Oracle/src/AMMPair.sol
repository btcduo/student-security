// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function balanceOf(address account) external view returns(uint256);
    function transfer(address to, uint256 value) external returns(bool);
    function transferFrom(address from, address to, uint256 value) external returns(bool);
}

contract AMMPair {
    error Identical_Tokens();
    error Zero_Token_Addr();
    error Reserve_OverFlow();
    error Insufficient_Liquidity();
    error Zero_Amounts();
    error Insufficient_Liquidity_Minted();
    error Insufficient_Liquidity_Remove();
    error Zero_Liquidity();
    error Zero_Address();
    error Insufficient_Amounts();
    error Invalid_Token();
    error Zero_Input();
    error Slippage();

    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 private constant FEE_DENOMINATOR = 1000;
    uint256 private constant FEE_NUMERATOR = 997; // 0.3% fee

    event Mint(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        uint256 amountIn,
        address indexed to,
        uint256 amountOut
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address _token0, address _token1) {
        if(_token0 == _token1) {
            revert Identical_Tokens();
        }
        if(_token0 == address(0) || _token1 == address(0)) {
            revert Zero_Token_Addr();
        }
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns(uint112, uint112) {
        return (reserve0, reserve1);
    }

    function _update(uint256 balance0, uint256 balance1) private {
        if(balance0 > type(uint112).max || balance1 > type(uint112).max) {
            revert Reserve_OverFlow();
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    function _mint(address to, uint256 liquidity) private {
        totalSupply += liquidity;
        balanceOf[to] += liquidity;
    }

    function _burn(address from, uint256 liquidity) private {
        balanceOf[from] -= liquidity;
        totalSupply -= liquidity;
    }

    function _min(uint256 x, uint256 y) private pure returns(uint256) {
        return x < y ? x : y;
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

    function _getAmountOut(
        uint256 amountInWithFee,
        uint112 _reserveIn,
        uint112 _reserveOut
    ) private pure returns(uint256 amountOut) {
        if(_reserveIn == 0 || _reserveOut == 0) {
            revert Insufficient_Liquidity();
        }
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = uint256(_reserveIn) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external returns(uint256 liquidity) {
        if(amount0Desired == 0 || amount1Desired == 0) {
            revert Zero_Amounts();
        }
        IERC20(token0).transferFrom(msg.sender, address(this), amount0Desired);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1Desired);
    
        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        if(totalSupply == 0) {
            liquidity = _sqrt(amount0Desired * amount1Desired);
        } else {
            uint256 liquidity0 = amount0Desired * totalSupply / _reserve0;
            uint256 liquidity1 = amount1Desired * totalSupply / _reserve1;
            liquidity = _min(liquidity0, liquidity1);
        }

        if(liquidity == 0) {
            revert Insufficient_Liquidity_Minted();
        }
        _mint(msg.sender, liquidity);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        _update(balance0, balance1);

        emit Mint(msg.sender, amount0Desired, amount1Desired, liquidity);
    }

    function removeLiquidity(
        uint256 liquidity,
        address to
    ) external returns(uint256 amount0, uint256 amount1) {
        if(liquidity == 0) {
            revert Zero_Liquidity();
        }
        if(liquidity > balanceOf[msg.sender]) {
            revert Insufficient_Liquidity_Remove();
        }
        if(to == address(0)) {
            revert Zero_Address();
        }

        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        amount0 = liquidity * _reserve0 / totalSupply;
        amount1 = liquidity * _reserve1 / totalSupply;
        if(amount0 == 0 || amount1 == 0) {
            revert Insufficient_Amounts();
        }

        _burn(msg.sender, liquidity);

        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        _update(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external returns(uint256 amountOut) {
        if(tokenIn != token0 && tokenIn != token1) {
            revert Invalid_Token();
        }
        if(amountIn == 0) {
            revert Zero_Input();
        }
        if(to == address(0)) {
            revert Zero_Address();
        }

        bool zeroForOne = (tokenIn == token0);

        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR / FEE_DENOMINATOR;

        if(zeroForOne) {
            amountOut = _getAmountOut(amountInWithFee, _reserve0, _reserve1);
            if(amountOut < minAmountOut) {
                revert Slippage();
            }
            IERC20(token1).transfer(to, amountOut);
        } else {
            amountOut = _getAmountOut(amountInWithFee, _reserve1, _reserve0);
            if(amountOut < minAmountOut) {
                revert Slippage();
            }
            IERC20(token0).transfer(to, amountOut);
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        _update(balance0, balance1);

        emit Swap(msg.sender, tokenIn, amountIn, to, amountOut); 
    }
}
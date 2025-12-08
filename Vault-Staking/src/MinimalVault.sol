// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title MinimalVault
/// @notice Single asset, min flation, Vault, shares implicit bookkeepping, 不单独发 ERC20.
contract MinimalVault is ReentrancyGuard {
    using SafeERC20 for IERC20;
    error ZeroAssetAddr();
    error AssetNotContract();
    error ZeroAssets();
    error ZeroReceiver();
    error ZeroShares();
    error InsufficientShares();
    error NoShares();

    /// @notice 底层资产, 例如 DAI / USDC
    IERC20 public immutable asset;

    /// @notice 记录所有用户存入的底层资产
    uint256 public totalUnderlying;

    /// @notice 全系统 share 总量
    uint256 public totalShares;

    /// @notice 单用户持有的 share 数量
    mapping(address => uint256) public userShares;

    /// @dev 用 1e18 作精度因子, 只用于展示 pricePerShare 等
    uint256 private constant PRECISION = 1e18;

    /// @param _asset Vault 对应的底层资产
    constructor(IERC20 _asset) {
        if(address(_asset) == address(0)) {
            revert ZeroAssetAddr();
        }
        if(address(_asset).code.length == 0) {
            revert AssetNotContract();
        }
        asset = _asset;
    }

    // === View Helpers === 

    /// @notice 当前 1 share 价值多少 asset (scaled by 1e18)
    function pricePerShare() public view returns(uint256) {
        if(totalUnderlying == 0 || totalShares == 0) {
            return PRECISION;
        }
        return (totalUnderlying * PRECISION) / totalShares;
    }

    /// @notice 模拟: 给定 assets, 将会铸造多少 shares
    function previewDeposit(uint256 assets) external view returns(uint256 shares) {
        shares = _convertToShares(assets, totalUnderlying, totalShares);
    }

    /// @notice 模拟: 给定 shares, 将会赎回多少 assets
    function previewWithdraw(uint256 shares) external view returns(uint256 assets) {
        assets = _convertToAssets(shares, totalUnderlying, totalShares);
    }

    /// @notice 用户当前持有的 shares
    function balanceOf(address user) external view returns(uint256) {
        return userShares[user];
    }

    /// @notice 当前 Vault 抽象下的底层资产总量
    function totalAssets() external view returns(uint256) {
        return totalUnderlying;
    }

    // === Core Logic ===

    /// @notice 用户存入底层资产, 获得 share
    /// @param assets 存入的底层资产数量
    /// @param receiver 接受 shares 的地址
    /// @return shares 铸造的 share 数量
    function deposit(
        uint256 assets,
        address receiver
    ) external nonReentrant returns(uint256 shares) {
        if(assets == 0) {
            revert ZeroAssets();
        }
        if(receiver == address(0)) {
            revert ZeroReceiver();
        }

        // 记账旧状态
        uint256 _totalUnderlying = totalUnderlying;
        uint256 _totalShares = totalShares;

        // 计算应该铸造多少 shares
        shares = _convertToShares(assets, _totalUnderlying, _totalShares);
        if(shares == 0) {
            revert ZeroShares();
        }

        // 从用户转入底层资产
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // 更新状态
        totalUnderlying = _totalUnderlying + assets;
        totalShares = _totalShares + shares;
        userShares[receiver] += shares;

        return shares;
    }

    /// @notice 用户用 shares 赎回底层资产
    /// @param shares 要赎回的 share 数量
    /// @param receiver 接受底层资产的地址
    /// @return assets 赎回的底层资产数量
    function withdraw(
        uint256 shares,
        address receiver
    ) external nonReentrant returns(uint256 assets) {
        if(shares == 0) {
            revert ZeroShares();
        }
        if(receiver == address(0)) {
            revert ZeroReceiver();
        }

        uint256 userBal = userShares[msg.sender];
        if(userBal < shares) {
            revert InsufficientShares();
        }

        // 记账旧状态
        uint256 _totalUnderlying = totalUnderlying;
        uint256 _totalShares = totalShares;
        if(_totalShares == 0) {
            revert NoShares();
        }

        // 计算需要给多少底层资产
        assets = _convertToAssets(shares, _totalUnderlying, _totalShares);
        if(assets == 0) {
            revert ZeroAssets();
        }

        // 更新状态(先减 shares/underlying 再转账) 
        userShares[msg.sender] = userBal - shares;
        totalShares = _totalShares - shares;
        totalUnderlying = _totalUnderlying - assets;

        // 转出底层资产
        asset.safeTransfer(receiver, assets);

        return assets;
    }

    // === Internal Math ===

    /// @dev 将 assets 换算成 shares; 初期或资金为 0 时按 1:1 处理
    function _convertToShares(
        uint256 assets,
        uint256 _totalUnderlying,
        uint256 _totalShares
    ) internal pure returns(uint256 shares) {
        if(assets == 0) {
            return 0;
        }
        if(_totalUnderlying == 0 || _totalShares == 0) {
            shares = assets;
        } else {
            shares = (assets * _totalShares) / _totalUnderlying;
        }
    }

    function _convertToAssets(
        uint256 shares,
        uint256 _totalUnderlying,
        uint256 _totalShares
    ) internal pure returns(uint256 assets) {
        if(shares == 0 || _totalShares == 0) {
            return 0;
        }

        assets = (shares * _totalUnderlying) / _totalShares;
    }
}

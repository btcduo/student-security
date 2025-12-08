// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract MinimalVault_Vuln_PoC2 is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAssetAddr();
    error AssetAddrNotContract();
    error ZeroTokens();
    error ZeroShares();
    error NoShares();
    error ZeroAddr();
    error InsufficientShares();

    IERC20 public immutable asset;

    uint256 public totalShares;

    mapping(address => uint256) public userShares;

    event Deposited(address indexed funder, address receiver, uint256 shares);
    event Withdrawn(address indexed funder, address receiver, uint256 tokens);

    uint256 private constant PRECISION = 1e18;

    constructor(IERC20 _asset) ERC20("SHARES MOCK", "MOCK") {
        if(address(_asset) == address(0)) {
            revert ZeroAssetAddr();
        }
        if(address(_asset).code.length == 0) {
            revert AssetAddrNotContract();
        }
        asset = _asset;
    }

    function pricePerShare() external view returns(uint256) {
        uint256 _totalUnderlying = _currentTotalUnderlying();
        uint256 _totalShares = totalShares;
        if(_totalShares == 0) {
            return PRECISION;
        }
        return (_totalUnderlying * PRECISION) / _totalShares;
    }

    function previewSharesPrice(uint256 tokens) external view returns(uint256 shares) {
        if(tokens == 0) {
            revert ZeroTokens();
        }
        uint256 _totalShares = totalShares;
        uint256 _totalUnderlying = _currentTotalUnderlying();
        if(_totalShares == 0 || _totalUnderlying == 0) {
            return shares = tokens;
        }
        return shares = (tokens * _totalShares) / _totalUnderlying;
    }

    function previewTokenPrice(uint256 shares) external view returns(uint256 tokens) {
        if(shares == 0) {
            revert ZeroShares();
        }
        uint256 _totalUnderlying = _currentTotalUnderlying();
        uint256 _totalShares = totalShares;
        if(_totalShares == 0) {
            revert NoShares();
        }
        tokens = (shares * _totalUnderlying) / _totalShares;
    }
    
    function _currentTotalUnderlying() public view returns(uint256) {
        return asset.balanceOf(address(this));
    }

    function deposit(address who, uint256 tokens) external nonReentrant returns(uint256 shares) {
        if(who == address(0)) {
            revert ZeroAddr();
        }
        if(tokens == 0) {
            revert ZeroTokens();
        }

        uint256 _totalUnderlying = _currentTotalUnderlying();
        uint256 _totalShares = totalShares;

        shares = _convertToShares(tokens, _totalUnderlying, _totalShares);

        asset.safeTransferFrom(msg.sender, address(this), tokens);
        
        totalShares = _totalShares + shares;
        userShares[who] += shares;
        _mint(who, shares);
        emit Deposited(msg.sender, who, shares);
    }

    function withdraw(address who, uint256 shares) external nonReentrant returns(uint256 tokens) {
        if(who == address(0)) {
            revert ZeroAddr();
        }
        if(shares == 0) {
            revert ZeroShares();
        }
        if(shares > userShares[msg.sender]) {
            revert InsufficientShares();
        }
    
        uint256 _totalUnderlying = _currentTotalUnderlying();
        uint256 _totalShares = totalShares;
        if(_totalShares == 0) {
            revert NoShares();
        }

        tokens = _convertToTokens(shares, _totalUnderlying, _totalShares);

        totalShares = _totalShares - shares;
        userShares[msg.sender] -= shares;
        _burn(msg.sender, shares);

        asset.safeTransfer(who, tokens);
        emit Withdrawn(msg.sender, who, tokens);
    }

    function _convertToShares(
        uint256 tokens,
        uint256 _totalUnderlying,
        uint256 _totalShares
    ) internal pure returns(uint256 shares) {
        if(tokens == 0) {
            revert ZeroTokens();
        }
        if(_totalUnderlying == 0 || _totalShares == 0) {
            return shares = tokens;
        }

        shares = (tokens * _totalShares) / _totalUnderlying;
    }

    function _convertToTokens(
        uint256 shares,
        uint256 _totalUnderlying,
        uint256 _totalShares
    ) internal pure returns(uint256 tokens) {
        if(shares == 0) {
            revert ZeroShares();
        }
        if(_totalShares == 0) {
            revert NoShares();
        }

        tokens = (shares * _totalUnderlying) / _totalShares;
    }
}
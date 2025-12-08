// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title LinearStaking
/// @notice 线性发放奖励的最小质押合约, 采用 Synthetix 风格 rewardPerToken 记账模型.
contract LinearStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error NotOwner();
    error ZeroStakingToken();
    error ZeroRewardToken();
    error StakingTokenNotContract();
    error RewardTokenNotContract();
    error ZeroOwner();
    error ZeroAmount();
    error InsufficientBalance();
    error NoReward();

    /// @notice 被质押的 token('Vault share' 的 ERC20 包装)
    IERC20 public immutable stakingToken;

    /// @notice 发放的奖励 token('Vault underlying')
    IERC20 public immutable rewardToken;

    /// @notice 合约 owner, 用于配置奖励速率等
    address public owner;

    /// @notice 当前全局奖励发放速率: 每秒发多少 rewardToken
    uint256 public rewardRate;

    /// @notice 上一次更新 rewardPerToken 的时间戳
    uint256 public lastUpdateTime;

    /// @notice 当前累积的 “每 1 个 staked token 对应的奖励”, 放大1e18
    uint256 public rewardPerTokenStored;

    /// @notice 所有用户的质押总量
    uint256 public totalStaked;

    /// @notice 每个用户质押了多少 stakingToken
    mapping(address => uint256) public balances;

    /// @notice 用户上一次结算时看到的 rewardPerTokenStored
    mapping(address => uint256) public userRewardPerTokenPaid;

    /// @notice 用户已积累但尚未领取的奖励
    mapping(address => uint256) public rewards;

    uint256 private constant PRECISION = 1e18;

    // === Events ===

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event OwnerUpdated(address indexed newOwner);

    // === Modifiers ===

    modifier onlyOwner() {
        if(msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if(account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // === Constructor ===

    constructor(IERC20 _stakingToken, IERC20 _rewardToken) {
        if(address(_stakingToken) == address(0)) {
            revert ZeroStakingToken();
        }
        if(address(_rewardToken) == address(0)) {
            revert ZeroRewardToken();
        }
        if(address(_stakingToken).code.length == 0) {
            revert StakingTokenNotContract();
        }
        if(address(_rewardToken).code.length == 0) {
            revert RewardTokenNotContract();
        }
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        owner = msg.sender;
    }

    // === View Functions ===

    /// @notice 当前时刻的 rewardPerToken (仅计算)
    function rewardPerToken() public view returns(uint256) {
        if(totalStaked == 0) {
            return rewardPerTokenStored;
        }

        uint256 timeDelta = block.timestamp - lastUpdateTime;
        uint256 _totalRewards = rewardRate * timeDelta;
        return rewardPerTokenStored + (_totalRewards * PRECISION) / totalStaked;
    }

    /// @notice 某个用户当前为止应得的奖励 (含未领)
    function earned(address account) public view returns(uint256) {
        uint256 userBalance = balances[account];
        uint256 rpt = rewardPerToken();

        uint256 paid = userRewardPerTokenPaid[account];
        uint256 pending = rewards[account];

        return (userBalance * (rpt - paid)) / PRECISION + pending;
    }

    // === Owner Functions ===

    /// @notice 设置/更新奖励发放速率(不带 duration 控制)
    /// @dev 调整前先把现有 rewardPerToken 结算到当前时间点
    function setRewardRate(uint256 _rewardRate)
        external
        onlyOwner
        updateReward(address(0))
    {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    /// @notice 更换 owner
    function setOwner(address newOwner) external onlyOwner {
        if(newOwner == address(0)) {
            revert ZeroOwner();
        }
        owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    /// @notice 质押 stakingToken
    function stake(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        if(amount == 0) {
            revert ZeroAmount();
        }

        totalStaked += amount;
        balances[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /// @notice 从质押中取回 stakingToken (不自动领取奖励)
    function unstake(uint256 amount)
        public
        nonReentrant
        updateReward(msg.sender)
    {
        if(amount == 0) {
            revert ZeroAmount();
        }
        uint256 bal = balances[msg.sender];
        if(bal < amount) {
            revert InsufficientBalance();
        }
        
        totalStaked -= amount;
        balances[msg.sender] = bal - amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /// @notice 领取累计奖励
    function claimReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if(reward == 0) {
            revert NoReward();
        }
        
        rewards[msg.sender] = 0;

        rewardToken.safeTransfer(msg.sender, reward);

        emit RewardPaid(msg.sender, reward);
    }

    /// @notice 一次性退出: 取消质押并领取奖励
    function exit() external {
        uint256 bal = balances[msg.sender];
        if(bal > 0) {
            unstake(bal);
        }

        if(rewards[msg.sender] > 0) {
            claimReward();
        }
    }
}
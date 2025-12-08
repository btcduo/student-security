// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract LinearStaking_Rewrite is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroTokenAddr();
    error ZeroRewardAddr();
    error TokenAddrNotContract();
    error RewardAddrNotContract();
    error NotOwner();
    error InsufficientAmount();
    error ZeroAmount();
    error NoRewards();

    /// @notice 等价于 Vault 中的 share
    IERC20 public immutable token;

    /// @notice 等价于 Vault 中的 token
    IERC20 public immutable reward;

    /// @notice 修改 rewardRate
    address public owner;

    /// @notice reward 指数 秒级
    uint256 public rewardRate;

    uint256 public lastUpdateTime;

    /// @notice 每个 share 可以领取多少 reward
    uint256 public rewardPerTokenStored;

    uint256 public totalStaked;

    uint256 public immutable PRECISION = 1e18;

    mapping(address => uint256) public userRewardPerTokenPaid;

    mapping(address => uint256) public balances;

    /// @notice 用户没有领取的 rewards
    mapping(address => uint256) public userRewards;

    constructor(IERC20 _token, IERC20 _reward) {
        if(address(_token) == address(0)) {
            revert ZeroTokenAddr();
        }
        if(address(_reward) == address(0)) {
            revert ZeroRewardAddr();
        }
        if(address(_token).code.length == 0) {
            revert TokenAddrNotContract();
        }
        if(address(_reward).code.length == 0) {
            revert RewardAddrNotContract();
        }
        token = _token;
        reward = _reward;
        owner = msg.sender;
    }

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
            userRewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    event RewardRateSet(uint256 _newRate);
    event Staked(address indexed caller, uint256 amount);
    event UnStaked(address indexed caller, uint256 amount);
    event Claimed(address indexed caller, uint256 amount);

    function rewardPerToken() public view returns(uint256) {
        if(totalStaked == 0) {
            return rewardPerTokenStored;
        }

        uint256 delta = block.timestamp - lastUpdateTime;
        uint256 _reward = rewardRate * delta;

        return rewardPerTokenStored + (_reward * PRECISION) / totalStaked;
    }

    function earned(address account) public view returns(uint256) {
        uint256 bal = balances[account];

        uint256 rpt = rewardPerToken();
        uint256 userRpt = userRewardPerTokenPaid[account];
        uint256 pending = userRewards[account];

        return bal * (rpt - userRpt) / PRECISION + pending;
    }

    function setRewardRate(uint256 _newRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _newRate;
        emit RewardRateSet(_newRate);
    }

    function stake(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        if(amount == 0) {
            revert ZeroAmount();
        }

        balances[msg.sender] += amount;
        totalStaked += amount;

        token.safeTransferFrom(msg.sender, address(this), amount);
        
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount)
        public
        nonReentrant
        updateReward(msg.sender)
    {
        if(amount == 0) {
            revert ZeroAmount();
        }
        
        uint256 bal = balances[msg.sender];
        if(amount > bal) {
            revert InsufficientAmount();
        }

        balances[msg.sender] = bal - amount;
        totalStaked -= amount;

        token.safeTransfer(msg.sender, amount);

        emit UnStaked(msg.sender, amount);
    }

    function claim() public nonReentrant updateReward(msg.sender) {
        uint256 rew = userRewards[msg.sender];
        if(rew == 0) {
            revert NoRewards();
        }

        userRewards[msg.sender] = 0;

        reward.safeTransfer(msg.sender, rew);

        emit Claimed(msg.sender, rew);
    }

    function exit() external {
        uint256 bal = balances[msg.sender];
        if(bal > 0) {
            unstake(bal);
        }
        if(userRewards[msg.sender] > 0) {
            claim();
        }
    }
}
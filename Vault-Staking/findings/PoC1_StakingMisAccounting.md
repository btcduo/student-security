## Title: Missing reward update in stake() causes reward mis-accounting and unfair contribution.
## 标题: 在stake() 被调用时缺少 updateReward(), 导致后来者瓜分属于早起质押者的奖励.

*前置条件:*
- 合约系统包含：
    reward: ERC20 奖励代币
    share: MinimalVault，用于将 reward 置换成 share
    st: 存在漏洞的 LinearStaking_Vuln_PoC1
    safeSt: 修复后的 LinearStaking_Rewrite
- 创建两名参与者：alice, bob
- 为两人各 mint 200 个 reward，并批准给对应的 staking / vault 合约
*复现治理缺失:*
1. 管理员将 st 与 safeSt 的 rewardRate 均设置为 60。
2. Alice：
    deposit 200 reward → 获取 200 share
    在两个合约中分别 stake 100 share
3. 时间推进 10 秒
4. Bob：
    deposit 200 reward → 获取 200 share
    在两个合约中分别 stake 100 share
5. 再次时间推进 10 秒
6. Alice 在两个合约中各 unstake 100 share
7. Bob 在两个合约中各 unstake 100 share
8. 检查奖励：
    Vulnerable 合约 st
        userRewards(alice) == 600
        userRewards(bob) == 600
    Safe 合约 safeSt
        userRewards(alice) == 900
        userRewards(bob) == 300
*安全含义(爆炸面):*
LinearStaking_Vuln_PoC1 的 stake() 未调用 updateReward()。
结果导致：
    奖励累计器未在新用户进场前推进到当前时间
    新用户 snapshot 到的是过期的 rewardPerToken 值
    晚质押者可以瓜分早期质押者在前一时段已经“赚到但尚未记录”的奖励
早期质押者损失奖励，晚进场者获得不合理的额外奖励。
奖励分配不再满足应有的「按 stake × time 比例」的公平性。
该错误属于典型的：
Reward Mis-accounting / Fairness Violation
如果攻击者频繁入场离场，可持续性偷取 honest stakers 的 reward。

## Short English Digest:
The stake() function does not call updateReward(), causing new stakers to inherit outdated reward snapshots.
This allows late participants to earn rewards for periods during which they were not staked.
As a result, early stakers lose part of their accrued rewards, leading to systemic reward mis-accounting and unfair distribution.
## Title: Vault Share Inflation
*前置条件*
- 合约系统包含:
    token: ERC20 原生代币
    safeVault: 修复后的 MinimalVault_Rewrite
    vulnVault: 存在漏洞的 MinimalVault_Vuln_PoC2
- 创建两名参与者: donor, attacker
- 为 donor mint 2000 个 token, 为 attacker mint 2 个 token
- attacker 给 safeVault 与 vulnVault 合约 approve 无限额度
*复现步骤*
1. donor: 给 两个合约 各转 1000 个 token
2. attacker: 
    在 两个合约中 各 deposite 1 token → 各 获取 1 share
    在 两个合约中 各 withdraw 1 share
3. 检查余额:
    Safe 合约 safeVault
        token.balanceOf(safeVault) == 1000
    Vulnerable 合约 vulnVault
        token.balanceOf(vulnVault) == 0
    Attacker
        token.balanceOf(attacker) == 1002
*影响*
- 在 vulnVault 中, 第一笔存款人可以将 vault 里全部真实余额提走, 包括任何其他渠道收入的资金.
- 任何后续质押者的资产都有可能被清空.
- 这类错误在真实协议中为 直接资产盗取 级别问题.
*安全含义/设计总结*
- vulnVault 不再满足`不通过 deposit 就不能获取 share, 不能提走资产 的不变量`
- 捐赠/误转 的资金 错误的参与到了 share 估值中, 而非单独处理.
- 建议: deposit/withdraw中用独立账本 totalUnderlying 进行记账, 其他收入单独记账, 避免被普通存款人拿走.

## Short English Digest:
The vulnerable vault derives totalUnderlying from asset.balanceOf(address(this)) instead of an internal ledger.
This causes any pre-existing donations or accidental transfers to be treated as part of the share-backed pool, allowing the first depositor to withdraw both their own deposit and all third-party funds.
As a result, external users’ tokens can be fully drained via inflated share value, which constitutes a direct fund theft vulnerability.
The vault should track totalUnderlying in internal storage and exclude non-deposit inflows from the share conversion path.
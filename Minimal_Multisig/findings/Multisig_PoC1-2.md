# Multisig PoC-1 & PoC-2

## 1. 场景与初始配置
- 合约: MinimalMultisigV2_Rewrite
- 初始成员 { address(this), a1 }
- 初始 threshold: 1 -> 通过多签流程修改为 2(2-of-2)
- 资金: 2 ETH 先转入 multisig

## 2. PoC-1 - lowSecurity 2-of-3 transferOutFunds
### 2.1 前置条件
- 当前 owner 集合: { this, a1 }
- threshold = 2

### 2.2 操作步骤(对应测试代码)
1. owner(this) 提案新增 a2: `proposeAddOwner(a2)`.
2. owner(this) + owner(a1) 依次 confirm, a2 正式加入, owner 数量变为 3.
3. owner(this) 提案把 2 ETH 全部转给 a3: `submit(a3, 2 ether, "")`.
4. owner(this) + owner(a1) 依次 confirm, 交易执行, 2 ETH 转给 a3.

### 2.3 结果与安全含义
- 结果:
    - Multisig 合约余额 变为 0.
    - a3 余额 增加 2 ETH.
- 含义:
    - owner 增多之后, threshold 阈值没有自动更新, 2-of-3 让资金被转出的条件变的宽松, 安全性弱化.
    - 风险类型: 治理策略.

## 3. PoC-2 - removeOwner 之后的 2-of-2 transferOk
### 3.1 前置条件
- 基于 PoC-1 之后的状态: owner = { this, a1, a2 }, threshold = 2, 合约余额 = 2 ETH.

### 3.2 操作步骤
1. owner(this) 提案移除 a2: `proposeRemoveOwner(a1)`.
2. owner(this), owner(a1) 依次 confirm, a1 被移除, owner 数量变为 2.
3. owner(this) 提案把 合约全部资产 转给 a3: `submit(a3, address(sig2).balance, "")`.
4. owner(this), owner(a2) 依次 confirm, 交易执行, 合约全部资产 转给 a3.

### 3.3 结果与安全含义
- 结果:
    - Multisig 合约余额 变为 0.
    - a3 余额增加 2 ETH.
- 含义:
    - 移除owner后, 只要threshold 不大于 owner 总数, 多签执行逻辑正常, 但配置变化可能未被治理层感知.
    - 如果移除owner前, 不保证owner count > threshold,当条件为 2-of-1, 则 因多签owner不足而无法进行提案后的任何操作.

## 4. 总结与后序加固

当前系统通过了多签逻辑验证，但：

1. 合约不会自动限制或引导 threshold 策略  
   - owner 数量增加不会触发阈值更新  
   - 容易从 2-of-2 弱化为 2-of-3

2. 系统缺少治理配置一致性的约束  
   - 移除 owner 后，虽然多签仍安全执行  
   - 但治理层可能未及时调整安全策略

建议方向：

A. 以治理策略限制阈值下限  
   - 建议 threshold ≥ ceil(owner 数量 * 2/3)  
   - 避免出现 3 owner 时 threshold = 2 的弱配置

B. 治理操作完成后需链下进行阈值评估  
   - owner 集合每次变更应伴随一次风险评估  
   - 不允许 ownerCount < threshold 的状态进入执行阶段

## 5. Bug & Fix - UnsafeParams
1. 问题场景:
    - 当 ownerCount == threshold, 调用 removeOwner 成功后, 阈值过高 (e.g., 3-of-2).
    - 阈值 高于 owner数量后, 任何交易都无法达到阈值, confirm不通过, 多签彻底瘫痪.
2. 问题根因:
    - removeOwner 在执行 remove 逻辑之前没有检查当 ownerCount <= threshold 时禁止删除的限制.
3. 解决方案:
    - 在 _removeOwnerInternal开头增加:
        - if(ownerList.length <= threshold) revert UnsafeParams();
    - 通过 test_removeOwner_revert_UnsafeParams() 验证:
        - 当 ownerListLength == threshold 时, 下一次调用 proposeRemoveOwner 会在多签执行中 revert UnsafeParams, 防止进入不可恢复状态.

### Short English digest
The design enforces that owner removal must not reduce the owner count below the active threshold before execution.
The system assumes that governance participants do not attempt unilateral downsizing in a way that blocks future approvals.
Unsafe removals are isolated by rejecting state-mutations when ownerCount <= threshold, preventing permanent execution lock.
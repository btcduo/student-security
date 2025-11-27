# Section 1 - Role & Target

## 1. Role
- MinimalMultisigV2_Rewrite(多签治理), GovernedVault(多签控制金库), ReceiverMock(下游测试合约)
## 2. Risk
- 单点owner或threshold为1,owner任意转出 / threshold大于owner数量, 多签无法处理交易 / owner, threshold的增删改不通过多签propose治理, owner权限提升 / 对外部的调用通过delegatecall, 多签上下文slot受外部影响 / 多个多签实例共享 storage slot, 跨实例重放.
## 3. Layer of contract
- 多签治理合约为 治理层, 多签控制金库合约为 资金层, 下游测试合约为 测试桩

## 4. Short English Digest
- The multisig governs owner management and proposal execution for downstream vaults.
- The governed vault restricts transfer logic to proposals approved by the multisig threshold.
- The ReceiverMock act as test recipients to exercise external-call, delegatecall, and replay surfaces.

# Section 2 - Execute progression
- ownerCount: 3(this, a1, a2), threshold: 2.
1. owner(this), submit `data = abi.encodeCall(ReceiverMock.setSum, (1)).
2. emit Submitted(submitter(this), to(ReceiverMock), value(0), data).
3. owner(this), confirmed.
4. emit Confirmed(confirmer(this), txId(0), approvedCount(1), needCount(2)).
    - approvedCount < needCount, return.
5. owner(a1), confirmed.
6. emit confirmed(confirmer(a1), txId(0), approvedCount(2), needCount(2)).
    - invoke _execute(txId).
        - rotating the executed state from false to true.
        - _execute relaying the transaction to target via a low-level call.
5. execution performed.
6. emit Executed(executor(a1), txId(0), isExecuted(true)).
7. ReceiverMock.sums(msg.sender) increased 0 -> 1.

## Short English Digest
- Proposals are sumbmitted by respective owners and accumulate confirmations until the active threshold is reached.
- Once the threshold is met, executes the queued transaction and marks it as executed.
- The Downstream contract receives the request and mutates its local state after verification.

# Section 3 - Trust & Gaps
- The system enforces that owner management and transfer logic must be mediated by multisig proposals, preventing privilege escalation.  
- The design assumes that downstream contracts are non-malicious and do not bypass context boundaries via delegatecall or re-entrant callbacks.  
- It isolates unsafe state mutation by rejecting proposals that match UnsafeParams before execution and by segregating per-instance state to eliminate replay and cross-context interference.

# Section 4 - PoC coverage & Mitigations
- PoC1: 2-of-3 在2次确认后资金转出, 安全等级一般, 增加更多owner后2-of-N, 安全等级明显降低, 资金安全不可控.
- PoC2: owner count 低于 threshold时, 提案以外操作永久锁死, 通过UnsafeParams防死锁.
- PoC3: 对外部调用使用delegatecall, 外部系统可以改写上下文的slots, 在对外调用逻辑的函数中限制使用call.
- PoC4: 确保提案返回的txId为当前上下文的索引, 证明txId在不同实例之间无法重放.

- The PoCs demondstrate how owner changes and misconfiguration of threshold can deadlock execution, validating the necessity of the UnsafeParams guard.
- Additional PoCs confirm that external executions are performed via call rather than delegatecall, and the cross-instance replay via reused txId is deterred.
- All PoCs collectively support the claim that governance and replay attack surfaces are constrained to their intended contexts.
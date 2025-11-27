### Section 1 - role & target
角色: 3个多签owners, governor(MinimalMultisigV2多签合约), 多签金库, 外部收款人.
解决问题: 
不设置owner导致的权限提升(任意调用方直接调用关键性逻辑函数).
单owner(恶意/误操作/私钥丢失)直接转出资金, 要求M-of-N批准才能转出资金或是增删改owners, 以及合约升级等.
日志记录, 使每个多签owner的行为都可以被观察到.

### Section 2 - execute progression
owner submits a proposal.
other owners confirm it.
threshold is reached.
multisig executes the call to the vault.
vault validates msg.sender == governor.
ether transfer occurs or reverts atomically.

### Section 3 - Trust & Gaps
The vault assumes the multisig governor address is correctly configured and not replaced by an attacker.
The system assumes that multisig owners keep their keys secure and do not collude to drain the vault.
The design lacks a maximum cap for owner count.
Individual owners can add a new owner without confirmation from others.
The design does not restrict targets for withdrawal calls.

### Section 4 - Multisig governance
The system enforces that owner management and value transfers must be mediated by multisig proposals and reach the approval threshold before execution.
The design assumes that governance participants do not configure a threshold larger than the active owner count, otherwise the system would enter a non-executable state.
The execution flow isolates external effects by validating authorization before state mutation, though it lacks an explicit reentrancy guard at this stage.
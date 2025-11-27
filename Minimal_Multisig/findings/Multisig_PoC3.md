# Multisig PoC-3

合约部署 `MinimalMultisigV2_Rewrite, ReceiverMock`.
owner集合 { this, a1, a2 }
操作步骤: 构造 data: `abi.encodeCall(ReceiverMock.setSum, (5))`, 记录 receiver合约中的全局变量(sums), 多签合约中的 ownerLength 与 threshold 值, address(this) 提案 -> address(this), a1 依次 授权确认 -> 执行成功, 断言 新sums值 == rcSums + 5, ownerLen 与 thresh 不变.

The system enforces that external executions are performed via call rather than delegatecall, so that only the callee’s own storage is mutated.
The design assumes that governance participants do not later introduce delegatecall-based execution paths without applying equivalent storage-safety controls.
The design isolates storage-corruption risk by keeping all multisig governance writes inside local functions, preventing downstream contracts from altering owners, thresholds, or queued transactions.
前置条件: 系统在 submit 中构造结构体时, 会将结构体push进当前合约自己的txs数组, txId只是该数组中结构体的索引.
攻击假设: 如果不同合约实例之间共享/污染存储槽(例如通过不当的proxy复用slot), 则同一个结构体的txId可能在不同实例中指向可执行记录, 从而产生跨实例重放风险.
安全含义: 本设计让每个多签实例维护各自独立的上下文txs存储, 使当前上下文的txId在另一个实例中指向的结构体不同或不存在, 从而隔离了跨实例重放的影响.

The design constructs Tx entries in the local txs array, in a way that each txId only indexes its correspoding local transaction.
The system assumes that each instance manages its own storage slots, and that any unintended or permissive slot-sharing(e.g., multiple multisig instances behind a misconfigured proxy) would enable cross-instance replays.
It isolates the impact of cross-instance replay by keeping the txs array in instance-local storage, thereby preventing any external contract from replaying cross-instance txId values.
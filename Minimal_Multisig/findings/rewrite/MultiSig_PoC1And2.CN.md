## 1）ownerCount 与 threshold 的安全边界
**前置条件：**
部署 MultiSig；owners = { address(this), a }；
初始 ownerCount = 2，threshold = 2。
**触发步骤：**
在 2-of-2 条件下：
任意 owner（例如 address(this)）发起 proposeRemoveOwner(a)，尝试删任意一名 owner；
交易直接触发 revert UnsafeParams()。
在 3-of-2 条件下：
先通过 proposeAddOwner + 多签流程把第三个 owner 加入，ownerCount: 2 → 3；
然后对其中一名 owner 发起 proposeRemoveOwner，按流程确认并执行一次，ownerCount: 3 → 2；
再次尝试对任意 owner 发起 proposeRemoveOwner，直接 revert UnsafeParams()。
阈值修改场景：
在 2-of-2 条件下：
提案 proposeModifyThreshold(1)，在多签通过后执行时于 _modifyThreshold 处 revert UnsafeParams()；
提案 proposeModifyThreshold(5)（大于当前 ownerCount）在创建阶段就被前置检查拒绝。
**影响：**
实际合约行为：
任何会导致 threshold > ownerCount 或 threshold < 2 的删除/阈值变更都会被 UnsafeParams 拦截，在状态写入前直接 revert；
如果缺失这些检查：
threshold > ownerCount 会导致后续所有提案都无法满足确认条件，多签进入永久锁死状态；
threshold < 2 会把多签退化成单签钱包，使“多方共管”的治理前提完全失效。
**安全含义：**
当前实现将 2 <= threshold <= ownerCount 作为显式不变量，在每次修改 owner/threshold 之前都强制校验；
PoC 证明了任何试图越界的配置都会被直接拒绝，防止系统在链上悄悄进入“锁死”或“假多签”的危险状态。

## 2）确认数不足时禁止执行提案
**前置条件：**
部署 MultiSig，owners = { address(this), a }；
ownerCount = 2，threshold = 2。
**触发步骤：**
某 owner 发起 proposeAddOwner 创建一条治理提案；
只让 1 名 owner 调用 confirm(txId)，导致当前确认数 < threshold；
紧接着尝试调用 execute(txId)。
**影响：**
实际合约行为：
execute 在内部重新统计确认数，发现 < threshold，触发 UnApprovedRequest revert，提案不会被执行；
如果在执行阶段不做这一步检查：
任意一个 owner 就可以在“确认数未达到阈值”的情况下执行提案，绕过多签约束，相当于把合约退化为“名义多签、实质单签”。
**安全含义：**
当前实现确保：每次 execute 都以“当前确认数 ≥ 阈值”为前置条件，否则拒绝对外执行任何 call；
PoC 验证了这一约束实际生效，避免因为实现疏忽导致的“少数签名就能落地治理变更”的隐性风险。

## 3）onlySelf 保护 owner/threshold 管理入口
**前置条件：**
部署 MultiSig，owners = { address(this), a }；
ownerCount = 2，threshold = 2；
addOwner/removeOwner/modifyThreshold 等管理函数使用 onlySelf 修饰，只允许合约自身调用。
**触发步骤：**
使用合法 owner（或者任何外部地址）直接调用 addOwner / removeOwner / modifyThreshold 这些只应被合约内部调用的函数；
**影响：**
实际合约行为：
由于调用方不是 address(this)，所有这些交易都会触发 NotSelf revert，无法修改 owner 或 threshold。
如果移除 onlySelf 或实现错误：
至少会导致任意 owner 可以跳过多签流程，直接修改 owner 列表和 threshold；
在缺少额外权限控制的情况下，甚至非 owner 地址也可能直接改写治理配置，完全破坏“合约通过提案流程统一管理配置”的设计。
**安全含义：**
当前实现把治理修改分成两层：
外部 owner 只能通过 propose*/confirm/execute 提案链路间接触发配置变更；
真正写入 owner/threshold 的逻辑函数只能由合约自身通过 onlySelf 调用。
PoC 证明了这种分层不是纸面设计：外部无法直接调用这些管理入口，只能走受多签约束的治理路径，减少了越权调用和随机骚扰带来的风险。

## 4）标准治理流程下提案可正确落地
**前置条件：**
部署 MultiSig，owners = { address(this), a }；
ownerCount = 2，threshold = 2。
**触发步骤：**
任意 owner 调用 submit 创建治理提案（例如 proposeAddOwner 或 proposeModifyThreshold）；
两名 owner 均调用 confirm(txId) 以满足阈值要求；
其中一名 owner 调用 execute(txId)。
**影响：**
实际合约行为：
交易在满足阈值检查后被成功执行，写入新的 owner / threshold 状态；
对应事件也按预期被记录，可用于链上审计和前端展示。
**安全含义：**
PoC 证明在约束条件满足时，多签治理仍然是“可用”的，不会被过度硬化锁死；
这保证了系统既能阻止不安全配置，也能在多数同意的前提下顺利落地产生预期的治理变更。
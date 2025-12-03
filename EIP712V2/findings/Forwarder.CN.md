## 安全边界
### DomainRegistry
- domainId 在构建合约时固定存储且不可改变, domainId与每个chainId只对应一个forwarder地址.
    - 风险点: domainId与chainId必须映射到正确的 forwarder 地址, 如果owner管理不当, 绑定错误forwarder地址, 则 依赖该合约的所有下级合约, 都将指向错误的forwarder.
    - 建议: forwarder的绑定必须被正确的处理, 引入多签, 由多个owner审查forwarder的绑定/更改流程, 是更好的安全模型设计
### Forwarder
- 交易在被forwarder转发前会经过校验, 确认参数有效才会继续往下传递;
    - 风险点: 验签完全依赖 SingatureRouter 判断, 如果 SignatureRouter 为恶意或配置错误, 携带错误签名的交易可能会被转发.
    - 建议: 将 SignatureRouter 视为系统及信任模块, 仅允许经过审计的多签/TimeLock治理升级, 或将其地址固定为不可升级.
- 签名的校验必须与包含forwarder合约信息(EIP712域分隔符)的digest 一同参与验签, 防跨域/跨合约的重放.
- 合约为每个UserOp.sender 维护一个 单调递增的 nonce, 在交易转发前 nonce 自增完成, 防同一交易重复转发.
- 交易被转发前留足 safeGas, 即使任何调用方/被调用方企图制造gas-griefing或通过消耗大量gas制造DoS的行为, safeGas也可以保证执行顺利完成.
- 需有pause() 函数, 当遇到紧急情况(如: DoS)时, 启用pause暂停所有交易的转发.
### SignatureRouter
- 对入参分流校验, signer为EOA时直接使用ECDSA校验, 为合约地址时则将参数传递给该合约地址, 由其自行校验(目标合约需要有 isValidSignature 函数).
    - 风险点: SignatureRouter 针对 合约地址的校验, 只比对该合约返回的魔法值, 是 0x1626ba7e 则认为签名有效, 否则拒绝签名, 如果合约always-magic, 则该合约自身的利益会受损.
### SecureRecipientV2
- 通过 DomainRegistry 提供的 domainId 与 block.chianid 查到 forwarder地址, execute logic 函数只有 onlyForwarded 可以调用.
    - 风险点: 依赖 DomainRegistry 的正确治理, 如果 DomainRegistry 的管理与 bad forwarder 勾结, 会使 SecureRecipientV2 的 关键函数 被 假forwarder操控.
### ERC20Token
- 内部自己构造 EIP712 域分隔符与 生成digest, 通过 SignatureRouter 对tokenOwner 做签名校验, nonce自维不依靠入参, 杜绝跨域/跨合约/重复调用 的重入攻击.
    - 风险点: mintToken 依赖管理的正确治理, 设计/管理不当会导致代币无限增发; 验签完全依赖 SingatureRouter 判断, 如果 SignatureRouter 为恶意或配置错误, 错误签名被承认.
### ReceiverMock
- 无, 仅测试用.

## Pause_DoS
### 前置条件:
- `ForwarderV2` 构造时注入 `owner = msg.sender`, 其中`msg.sender` 为 测试用例 `Forwarder_PoC.address(this)`.
### 治理误操作假设:
- `address(this)` 调用 `setPause()` 设置 `pause = true`.
### 安全含义(爆炸面):
- `ForwarderV2` 的 `pause` 在 系统正常的情况下被 不受控制的 `owner` 设置为 `true` 会导致整个系统永久型的不可控(锁死).
- 该PoC证明, 单签owner的不可控制性, 可以导致 forwarder 会进入到 锁死 状态.

## 未知forwarder交易转发被拦截
### 前置条件:
- 部署 `DomainRegistry registry` 构造时生成`domainId`, 构造中设置 address(this) 为 owner, `ForwarderV2 fwd` 构造时注入 `registry` 并拿到 `domainId` 构造中设置 address(this) 为 owner, `SecureRecipientV2 rcp` 构造时注入 `registry` 并拿到 `domainId`, `ReceiverMockV2 rc`, `ERC20PermitMock token0`, 构造中设置 address(this) 为 owner, `ValidatorMock validator`
- 调用: `registry.registerDomain(block.chainid, address(ForwarderV2)` 绑定 `ForwarderV2` 到映射 `forwarderOf[domainId][block.chainid]`
### 攻击假设: 
- `MalForwarder1 mfwd` 部署.
- `UserOp op` 结构体构造: `({sender: alice, to: ReceiverMockV2, value: 0, gasLimit: 450_000, nonce: 0, deadline: block.timestamp + 2, data: ""})`
- `PermitParams p` 结构体构造: `({owner: t_owner, spender: ReceiverMockV2, value: 0, deadline: block.timestamp + 2, v: v, r: r, s: s})` vrs 来自 t_ownerPK 的签名.
- `alice` 对 `op` 结构体签名.
- 所有字段均有效的情况下, mfwd 转发交易.
- `address(this)` 调用 `mfwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig)`.
- revert: NotTrustedForwarder.
### 安全含义(爆炸面):
- SecureRecipientV2 依赖 DomainRegistry 正确的管理forwarder地址, 防止跨链的forwarder转发交易, 形成重放攻击, 或者任意恶意forwarder转发坏交易, 使 SecureRecipient 被垃圾交易占满gas通道, 形成DoS.
- 该PoC证明, 即使 Forwarder 为恶意合约, 试图转发请求, 但只要没有被 DomainRegistry 绑定, 该forwarder转发的请求就会被正确的隔离, 从根源上防止了跨域, 跨合约的重放攻击.

## DomainRegistry 治理错误
### 前置条件:
- 部署 `DomainRegistry registry` 构造时生成`domainId`, 构造中设置 address(this) 为 owner, `ForwarderV2 fwd` 构造时注入 `registry` 并拿到 `domainId` 构造中设置 address(this) 为 owner, `SecureRecipientV2 rcp` 构造时注入 `registry` 并拿到 `domainId`, `ReceiverMockV2 rc`, `ERC20PermitMock token0`, 构造中设置 address(this) 为 owner, `ValidatorMock validator`
- 生成地址密钥对 `alice, alicePK`, `t_owner, t_ownerPK`
- 调用: `registry.registerDomain(block.chainid, address(ForwarderV2)` 绑定 `ForwarderV2` 到映射 `forwarderOf[domainId][block.chainid]`
### 治理误操作假设:
- `ForwarderV2 forgedFwd` 部署.
- `address(this)` 调用 `registry.updateDomain(block.chainid, address(forgedFwd))`
- `UserOp op` 结构体构造: `({sender: alice, to: ReceiverMockV2, value: 0, gasLimit: 450_000, nonce: 0, deadline: block.timestamp + 2, data: ""})`
- `PermitParams p` 结构体构造: `({owner: t_owner, spender: ReceiverMockV2, value: 0, deadline: block.timestamp + 2, v: v, r: r, s: s})` vrs 来自 t_ownerPK 的签名.
- `alice` 对 `op` 结构体签名.
- 所有字段均有效的情况下, fwd 转发交易.
- `address(this)` 调用 `fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig)`
- 在 `fwd` 对入参校验时, `reg.forwarderOf(domainId, block.chainid) != address(this)`, revert: BadDomainId.
### 安全含义(爆炸面):
- `ForwarderV2` 依赖 `DomainRegistry` 正确的将自身地址与对应 `chainId` 绑定到映射中, 只在 `DomainRegistry` 绑定的地址正确时才转发交易, 从自身层面杜绝 `DomainRegistry` 管理缺失带来的滥用风险.
- 该PoC证明了, ForwarderV2 只在 DomainRegistry 绑定的 forwarder 地址为自身地址时, 才会转发交易, 避免了 DomainRegistry 错误配置的滥用风险 以及 跨合约/跨链的重放攻击.

## DomainRegistry 治理错误 + MalForwarder1 转发交易 + 不验证签名
### 前置条件:
- 部署 `DomainRegistry registry` 构造时生成`domainId`, 构造中设置 address(this) 为 owner, `ForwarderV2 fwd` 构造时注入 `registry` 并拿到 `domainId` 构造中设置 address(this) 为 owner, `SecureRecipientV2 rcp` 构造时注入 `registry` 并拿到 `domainId`, `ReceiverMockV2 rc`, `ERC20PermitMock token0`, 构造中设置 address(this) 为 owner, `ValidatorMock validator`
- 生成地址密钥对 `alice, alicePK`, `t_owner, t_ownerPK`
- 调用: `registry.registerDomain(block.chainid, address(ForwarderV2)` 绑定 `ForwarderV2` 到映射 `forwarderOf[domainId][block.chainid]`
- 给 `address(this)` deal `10 ether`.
### 攻击假设:
- `MalForwarder1 mfwd` 部署.
- `address(this)` 调用 `registry.updateDomain(block.chainid, address(mfwd))`
- `UserOp op` 结构体构造: `({sender: alice, to: address(rc), value: 1 ether, gasLimit: 450_000, nonce: 0, deadline: block.timestamp + 2, data: abi.encodeCall(ReceivermockV2.deposit, ())})`
- `op.sender` 字段 篡改为 `address(0xb0b)`
- `PermitParams p` 结构体构造: `({owner: t_owner, spender: ReceiverMockV2, value: 0, deadline: block.timestamp + 2, v: v, r: r, s: s})` vrs 来自 t_ownerPK 的签名.
- `alice` 对 `op` 结构体签名.
- `address(this)` 调用 `mfwd.handleUserOpViaRecipientV2{value: 1 ether}(address(rcp), op, p, sig)`
- `rcp` 收到 请求后, `registry` 的错误配置使 `mfwd` 绕过 `onlyForwarded`, `rcp` 通过 `IForwarder(msg.sender).digest(op)` 拿到 `digest` 并再次对 `op.sender` 进行验签.
- revert: RCP_BadSig.
### 安全含义(爆炸面):
- `SecureRecipient` 不对 `registry` 与 `fwd` 百分百信任, 再验签的行为 杜绝了 `registry` + `fwd` 联合作恶 篡改 `op.sender` 的可能性.

## MalForwarder1 不设 safeGas + MalReceiver4 gas-griefing
### 前置条件:
- 部署 `DomainRegistry registry` 构造时生成`domainId`, `ForwarderV2 fwd` 构造时注入 `registry` 并拿到 `domainId`, `SecureRecipientV2 rcp` 构造时注入 `registry` 并拿到 `domainId`, `ReceiverMockV2 rc`, `ERC20PermitMock token0`, `ValidatorMock validator`
- 生成地址密钥对 `alice, alicePK`, `t_owner, t_ownerPK`
- 调用: `registry.registerDomain(block.chainid, address(ForwarderV2)` 绑定 `ForwarderV2` 到映射 `forwarderOf[domainId][block.chainid]`
- 给 `address(this)` deal `10 ether`.
### 攻击假设:
- 部署 `MalForwarder1 mfwd`, MalReceiver4 mrc
- `UserOp op` 结构体构造: `({sender: attacker, to: address(mrc), value: 0, gasLimit: 450_000, nonce: 0, deadline: block.timestamp + 2, data: abi.encodeCall(Malreceiver4.burnGas, ())})`
- `alice` 对 `op` 结构体签名.
- `address(this)` 调用 `mfwd.handleUserOp2(op, sig)`.
- 执行成功, `burnGas` 在 `gasleft() < 500_000` 时 返回, 消耗gas量: 1040021120
### 安全含义(爆炸面):
- Forwarder 在不设置 safeGas 的情况下转发交易, 任意caller 调用 callee 中的重逻辑可造成 gas-griefing, 甚至DoS.
- 本项目的 ForwarderV2 通过在执行前计算 safeGas 并将 gasLimit 限制在安全区间内, 防止同类攻击在生产环境中发生.

## MalForwarder 篡改 calldata
### 前置条件:
- 部署 `DomainRegistry registry` 构造时生成`domainId`, 构造中设置 address(this) 为 owner, `ForwarderV2 fwd` 构造时注入 `registry` 并拿到 `domainId` 构造中设置 address(this) 为 owner, `SecureRecipientV2 rcp` 构造时注入 `registry` 并拿到 `domainId`, `ReceiverMockV2 rc`, `ERC20PermitMock token0`, 构造中设置 address(this) 为 owner, `ValidatorMock validator`
- 生成地址密钥对 `alice, alicePK`, `t_owner, t_ownerPK`
- 调用: `registry.registerDomain(block.chainid, address(ForwarderV2)` 绑定 `ForwarderV2` 到映射 `forwarderOf[domainId][block.chainid]`
- 给 `address(this)` deal `10 ether`.
### 攻击假设:
- 部署 `MalForwarder1 mfwd`
- address(this) 调用 registry.updateDomain(block.chainid, address(mfwd))
- `UserOp op` 结构体构造: `({sender: alice, to: ReceiverMockV2, value: 1 ether, gasLimit: 450_000, nonce: 0, deadline: block.timestamp + 2, data: abi.encodeCall(ReceivermockV2.deposit, ())})`
- `alice` 对 `op` 结构体签名.
- `PermitParams p` 结构体构造: `({owner: t_owner, spender: ReceiverMockV2, value: 0, deadline: block.timestamp + 2, v: v, r: r, s: s})` vrs 来自 t_ownerPK 的签名.
- address(this) 调用 mfwd.handleUserOpWithBadData{value: 1 ether}(address(rcp), op, p, sig)
    - mfwd 合约在转发请求前:
        bytes19 badSender = bytes19(0xffffffffffffffffffffaaaaaaaaaaaaaaaaaa);
        bytes memory callData = abi.encodePacked(op.data, badSender);
- 在 ReceiverMockV2 中, 收到请求后尝试取出 _msgSender, 触发 msg.data.length < 24, revert: RCPV2_BadDataLength
### 安全含义(爆炸面):
- 如果上层传入的data是被篡改过的, 资金可能会被存入不存在的账户导致永久锁死.
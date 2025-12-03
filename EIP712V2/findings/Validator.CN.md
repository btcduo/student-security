## InvalidSig BalanceIncreased
### 前置条件:
- 部署 `DomainRegistry registry` 构造时生成`domainId`, 构造中设置 address(this) 为 owner, `ForwarderV2 fwd` 构造时注入 `registry` 并拿到 `domainId` 构造中设置 address(this) 为 owner, `SecureRecipientV2 rcp` 构造时注入 `registry` 并拿到 `domainId`, `ReceiverMockV2 rc`, `ERC20PermitMock token0`, 构造中设置 address(this) 为 owner, `MalValidator2 badAlice`, `MalValidator2 badOwner`
- 生成地址密钥对 `alice, alicePK`, `t_owner, t_ownerPK`, `attacker, attackerPK`
- 调用: `registry.registerDomain(block.chainid, address(ForwarderV2)` 绑定 `ForwarderV2` 到映射 `forwarderOf[domainId][block.chainid]`
- 给 `address(this)` deal `10 ether`.
### 攻击假设:
- `UserOp op` 结构体构造: `({sender: address(badAlice), to: address(rc), value: 1 ether, gasLimit: 450_000, nonce: 0, deadline: block.timestamp + 2, data: abi.encodeCall(ReceiverMockV2.deposit, ())})`
- 构造无效签名, bytes memory sig = bytes("idiot").
- `PermitParams p` 结构体构造: `({owner: t_owner, spender: address(rc), value: 0, deadline: block.timestamp + 2, v: v, r: r, s: s})` vrs 来自 t_ownerPK 的签名.
- address(this) 调用 fwd.handleUserOpViaRecipientV2{value: 1 ether}(address(rcp), op, p, sig)
- badAlice 不验证签名直接返回 0x1626ba7e
- 执行成功, rc.balanceOf(address(badAlice)) 增加 0 → 1 ether;
### 安全含义(爆炸面):
- badAlice 不验签的行为会导致无效signature的交易被执行成功, funder 资金损失.
- 该风险完全来自 badAlice 合约自身实现inValidSignature 时不进行验证, SignatureRouter 只负责根据1271标准路由并检查返回魔术, 不为下级合约的 实现失策行为负责.

## Always Magic badOwner Lost Funds
### 前置条件:
- 部署 `DomainRegistry registry` 构造时生成`domainId`, 构造中设置 address(this) 为 owner, `ForwarderV2 fwd` 构造时注入 `registry` 并拿到 `domainId` 构造中设置 address(this) 为 owner, `SecureRecipientV2 rcp` 构造时注入 `registry` 并拿到 `domainId`, `ReceiverMockV2 rc`, `ERC20PermitMock token0`, 构造中设置 address(this) 为 owner, `MalValidator2 badAlice`, `MalValidator2 badOwner`
- 生成地址密钥对 `alice, alicePK`, `t_owner, t_ownerPK`, `attacker, attackerPK`
- 调用: `registry.registerDomain(block.chainid, address(ForwarderV2)` 绑定 `ForwarderV2` 到映射 `forwarderOf[domainId][block.chainid]`
- 给 `address(this)` deal `10 ether`.
### 攻击假设:
- address(this) 调用 `token0.mintTokenOf(address(badOwner), 3000)`
- 构造 `bytes memory data = abi.encodeCall(ReceiverMockV2.transferFrom, address(token0), address(badOwenr), attacker, 2999)`
- `UserOp op` 结构体构造: `({sender: address(badAlice), to: address(rc), value: 0, gasLimit: 450_000, nonce: 0, deadline: block.timestamp + 2, data: data})`
- `PermitParams p` 结构体构造: `({owner: address(badOwner), spender: address(rc), value: 3000, deadline: block.timestamp + 2, v: v, r: r, s: s})` vrs 来自 t_ownerPK 的签名.
- address(this) 调用 `fwd.handleUserOpViaRecipientV2(address(rcp), op, p, sig)`
- badOwner, 无条件返回 `0x1626ba7e`
- token0.allowance(address(badOwner), address(rc)) 被消耗 3000 → 1
- token0.balanceOf(address(badOwner)), 减少 3000 → 1
- token0.balanceOf(attacker), 增加 0 → 2999
- 执行成功.
### 安全含义(爆炸面):
- badOwner 不验签的行为会导致无效signature的交易被执行成功, badOwner 自身资金损失.
- 该风险局限与 badOwner 本身的 always-magic 行为 等同于自身放弃了签名约束.
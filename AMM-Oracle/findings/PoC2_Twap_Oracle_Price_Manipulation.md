## PoC: TWAP Oracle Preventing The Attacker From Manipulating The Price And Draining The Consumer's assets
### CN part
*前置条件*
- 系统包含合约 { AMMPair_Rewrite, TwapOracle_Rewrite, LendingPool_Rewrite(Consumer) }
- 一个 funder 地址, 为AMM合约添加 10000 HODL + 20000 USDT 的流动性
- consumer 合约储备了 200_000_000 的 USDT 储备
*攻击假设*
- 存在一个 attacker 地址, 该地址 提前准备好 5000 个 HODL 代币
- 10秒后 将 5000 个HODL全部作为 collateral tokens 质押到 Consumer 合约中
- 2秒后 攻击者从闪电贷筹集了 50_000_000 个 USDT 并调用 AMMPair.swap() 将 USDT 换为 HODL
- 调用 TwapOracle.update() 扭曲价格成功
- 调用 Consumer.borrwWithTwap() 试图以被扭曲后的价格借出 资产, 但 TWAP窗口尚未推进, 被 Consumer.TwapNotUpdate() 自定义报错拦截
*影响*
- 现在 PoC 只证明 单次闪电贷 + 同窗口拉盘 这种 classic 模式会被 TWAP 拦截；
- 对长时间操纵、多池子协同这种复杂场景，还没有做经济性评估

### Short English Digest
This PoC shows that the TWAP-based borrowing path prevents the same AMM price-manipulation attack that succeeds against the spot oracle. The attacker deposits HODL as collateral, uses a large flash-loaned USDT position to push the AMM price to an extreme level, and calls `TwapOracle.update()` in an attempt to lock in the distorted price. When the attacker then calls `borrowWithTwap`, the lending pool checks that the TWAP window has not advanced and reverts with `TwapNotUpdate`, so no debt is issued and the pool’s USDT reserves remain intact. This behavior demonstrates that enforcing a time-weighted oracle with a progressing window can effectively block “single-block pump-and-borrow” style attacks, although additional measures (longer windows, multi-source feeds, and sanity checks on price moves) are still required in a real deployment.

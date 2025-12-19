## PoC: Spot Oracle Causing Price Manipulation By An Attacker.
*前置条件*
- 系统包含合约 { AMMPair_Rewrite, SpotOracle_Rewrite, Consumer_Rewrite }
- 一个 funder 地址, 为AMM合约添加 10000 HODL + 20000 USDT 的流动性
- consumer 合约储备了 200_000_000 的 USDT 储备
*攻击步骤*
- 有两个用户地址并分别添加流动性, 扩大流动池: 
    - user1 → 5000 HODL + 10000 USDT
    - user2 → 25000 HODL + 50000 USDT
- 调用 spot oracle 的 update() 更新价格
- 这时一名 attacker 介入, 准备 5348 个 HODL 价值约 10696 USDT 并将其作为 collateral 质押到 Consumer 合约中
- 调用 伪闪电贷(在同一个时间戳内应完成相应代币的`borrow→repay`) 筹集 50_000_000 个 USDT
- 调用 AMM.swap 将 闪电贷资金全部存入到池子中, 池子中的流动性大概变成 672 HODL : 50_260_000 USDT ≈ 1 HODL = 74791 USDT
- 攻击者调用 spot oracle update() 更新价格
- 攻击者用 提前准备好的 5348 个 HODL 借出Consumer几乎所有的 USDT 储备
- 攻击者调用 AMM.swap 将 持有的 HODL 全部换回 USDT 并还闪电贷本金+5%手续费
*影响*
- 断言: assertGt(usdt.balanceOf(attacker), cons_usdtVault * 9 / 10); 说明 攻击者本次用了 10696 USDT 的成本, 最终成功拿走了 Consumer 总 USDT 储备的 90% 以上
- 断言: assertLt(cons_reservedUsdt, cons_usdtVault * 5 / 1000); 说明 Consumer 本次损失 高达 99.5%
- 获利者: 攻击者本次获利金额高达至少: 180_000_000 USDT, 损失者: Consumer剩余储备不足原储备(200_000_000)的0.5%, AMMPair: 币对价格保持不变, 赚取两次 swap 的 0.3% 手续费
*根因*
- Consumer 获价来源仅靠 SpotOracle , 现价被攻击者通过闪电贷的方式操控, 最终导致损失发生.

## Short English Digest
*Description*
The SpotOracle contract is used to get the price of the token pairs in the AMMPair contract, supplying the price of tokens to third-party contracts like Consumer that do not get quotes itself.
However the SpotOracle only computes the price with the current value between two tokens.
Due to the Consumer naively trusts the SpotOracle's provided price, enabling a critical vulnerability below the scenario.
*Scenario*
Alice, an attacker, prepare 5348 HODL amount, then deposit the tokens as the "collateral" in the Consumer which is holding debt value about 200 million.
Alice invokes the FlashLoan function to collect 50 million of the USDT token, then calls AMMPair.swap() with 50 million USDT.
Hence the token pair's liquidity updated like 672 HODL and 50 million plus 260 thousand USDT, meaning the price is successfully changed by Alice.
After that, the attacker effectively calls orac0.update() to keep the new price as well as invokes the cons.borrowWithSpot() under a manipulated price.
Ultimately, 90 per cent assets of the Consumer's USDT has stolen to the attacker after repaying the FlashLoan by the attacker.
*Root Cause*
The Consumer's source of prices are limited to the SpotPrice, which allows any user can drain the tokens of the Consumer's debt tokens under a twisted token price.
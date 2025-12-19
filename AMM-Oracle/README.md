*Model Introduction*
- A Minimal AMM + Oracle + LendingPool + PoC(Price Manipulation differ behavior under SpotOracle and TwapOracle)
*Contract List(Effect)*
- src/rewrite/AMMPair_Rewrite : `Supports adding liquidity, removing liquidity, and swapping between tokenA and tokenB based on the current price implied by the reserve balances.`
- src/rewrite/SpotOracle_Rewrite : `Get the spot price of the token by invoking update() from AMMPair_Rewrite, supplying recorded spot price to the third-party implementation.`
- src/rewrite/TwapOracle_Rewrite : `Computes the TWAP-based price of the token by invokin update() from AMMPair_Rewrite, supplying recorded TWAP price to the third-party implementation.`
- src/rewrite/LendingPool_Rewrite : `A minimal lending pool allows users to deposit/withdraw only tokenA as 'collateral', and to borrow/repay only tokenB as 'debt'. The valuation can be based on either the spot price or a TWAP price.`
*Test*
- cd AMM-Oracle
- forge test -vv
*PoC Summary*
- PoC1 : `The LendingPool calculates the debt value using the token's spot price, which is provided by the SpotOracle, resulting in price manipulation being happened and the LendingPool's debt reserves being drained.`
- PoC2 : `The LendingPool calculates the debt value using the token's TWAP-based price provided by the TwapOracle. Since the pre-validation of the borrowWithTwap() eoforces that the new timestamp must be greater than the last timestamp, thereby preventing the user from borrowing the debt when no time has elapsed.`
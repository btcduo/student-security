*Slither Report*
**INFO:Detectors**
- performs a multiplication on the result of a division >> `SAFE`
- uses a dangerous strict equality: _reserveIn == 0 || _reserveOut == 0 (src/rewrite/AMMPair_Rewrite.sol#94) >> `Checking reserved token amount both greater than zero: SAFE`
- uses a dangerous strict equality: liquidity == 0 (src/rewrite/AMMPair_Rewrite.sol#107) >> `Calculating shares when the liquidity is empty: SAFE`
- uses a dangerous strict equality: lastUpdateAt == 0 (src/rewrite/SpotOracle_Rewrite.sol#61) / (src/rewrite/SpotOracle_Rewrite.sol#68) / (src/rewrite/TwapOracle_Rewrite.sol#87) >> `SAFE`
- Reentrancy in ... >> `A modier lock() has defined for core functions(such as addLiquidity, removeLiquidity and swap) in AMMPair_Rewrite.sol , due to the system is only used to show how the system works and when price manipulation happens. Hence we didn't import Reentrancy Guard for everywhere: SAFE`
- uses timestamp for comparisons >> `SAFE`
- Interface without SafeERC20 library >> `We know that import OpeZeppelin's SafeERC20 library will extend the protocol's competability with widely-used tokens. However, in minimal version we only accept native ERC20 tokens, which is good for observing issues: SAFE`
**NOTE**
- all 'SAFE' classifications are scoped strictly to this minimal, non-production prototype and would require reassessment in a permissionless deployment.
--- Slither Result ---
duobtc@duodemac-mini AMM-Oracle % slither . --filter-paths "lib"
'forge clean' running (wd: /Volumes/data/code/solidity/Stage9/9.15/AMM-Oracle)
'forge config --json' running
'forge build --build-info --skip */test/** */script/** --force' running (wd: /Volumes/data/code/solidity/Stage9/9.15/AMM-Oracle)
INFO:Detectors:
LendingPool_Rewrite.borrowWithSpot(uint256) (src/rewrite/LendingPool_Rewrite.sol#159-183) performs a multiplication on the result of a division:
	- collValue = coll * price / 1e18 (src/rewrite/LendingPool_Rewrite.sol#166)
	- maxEarn = collValue * LTV / 1e18 (src/rewrite/LendingPool_Rewrite.sol#168)
LendingPool_Rewrite.borrowWithTwap(uint256) (src/rewrite/LendingPool_Rewrite.sol#187-213) performs a multiplication on the result of a division:
	- collValue = coll * price / 1e18 (src/rewrite/LendingPool_Rewrite.sol#196)
	- maxEarn = collValue * LTV / 1e18 (src/rewrite/LendingPool_Rewrite.sol#198)
LendingPool_Rewrite.withdrawCollateralWithSpot(uint256) (src/rewrite/LendingPool_Rewrite.sol#236-267) performs a multiplication on the result of a division:
	- newCollValue = newColl * price / 1e18 (src/rewrite/LendingPool_Rewrite.sol#256)
	- debt * 1e18 > newCollValue * LIQ_THRESHOLD (src/rewrite/LendingPool_Rewrite.sol#257)
LendingPool_Rewrite.withdrawCollateralWithTwap(uint256) (src/rewrite/LendingPool_Rewrite.sol#269-296) performs a multiplication on the result of a division:
	- newCollValue = newColl * price / 1e18 (src/rewrite/LendingPool_Rewrite.sol#281)
	- debt * 1e18 > newCollValue * LIQ_THRESHOLD (src/rewrite/LendingPool_Rewrite.sol#284)
LendingPool_Rewrite.getHealthFactorWithSpot(address) (src/rewrite/LendingPool_Rewrite.sol#299-318) performs a multiplication on the result of a division:
	- collValue = coll * price / 1e18 (src/rewrite/LendingPool_Rewrite.sol#315)
	- collValue * LIQ_THRESHOLD / debt / 1e18 (src/rewrite/LendingPool_Rewrite.sol#317)
LendingPool_Rewrite.getHealthFactorWithTwap(address) (src/rewrite/LendingPool_Rewrite.sol#320-341) performs a multiplication on the result of a division:
	- collValue = coll * price / 1e18 (src/rewrite/LendingPool_Rewrite.sol#338)
	- collValue * LIQ_THRESHOLD / debt / 1e18 (src/rewrite/LendingPool_Rewrite.sol#340)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#divide-before-multiply
INFO:Detectors:
AMMPair_Rewrite._getAmountOut(uint256,uint256,uint256) (src/rewrite/AMMPair_Rewrite.sol#89-101) uses a dangerous strict equality:
	- _reserveIn == 0 || _reserveOut == 0 (src/rewrite/AMMPair_Rewrite.sol#94)
AMMPair_Rewrite._mint(address,uint256) (src/rewrite/AMMPair_Rewrite.sol#103-113) uses a dangerous strict equality:
	- liquidity == 0 (src/rewrite/AMMPair_Rewrite.sol#107)
SpotOracle_Rewrite.getPrice0() (src/rewrite/SpotOracle_Rewrite.sol#60-65) uses a dangerous strict equality:
	- lastUpdateAt == 0 (src/rewrite/SpotOracle_Rewrite.sol#61)
SpotOracle_Rewrite.getPrice1() (src/rewrite/SpotOracle_Rewrite.sol#67-72) uses a dangerous strict equality:
	- lastUpdateAt == 0 (src/rewrite/SpotOracle_Rewrite.sol#68)
TwapOracle_Rewrite.getCurrentCumulative() (src/rewrite/TwapOracle_Rewrite.sol#82-100) uses a dangerous strict equality:
	- lastUpdateAt == 0 (src/rewrite/TwapOracle_Rewrite.sol#87)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
INFO:Detectors:
Reentrancy in AMMPair_Rewrite.removeLiquidity(uint256,address) (src/rewrite/AMMPair_Rewrite.sol#191-227):
	External calls:
	- t0 = token0.transfer(to,amount0) (src/rewrite/AMMPair_Rewrite.sol#212)
	- t1 = token1.transfer(to,amount1) (src/rewrite/AMMPair_Rewrite.sol#213)
	State variables written after the call(s):
	- _update(balance0,balance1) (src/rewrite/AMMPair_Rewrite.sol#224)
		- reserve0 = uint112(balance0) (src/rewrite/AMMPair_Rewrite.sol#85)
	AMMPair_Rewrite.reserve0 (src/rewrite/AMMPair_Rewrite.sol#34) can be used in cross function reentrancies:
	- AMMPair_Rewrite._update(uint256,uint256) (src/rewrite/AMMPair_Rewrite.sol#81-87)
	- AMMPair_Rewrite.getReserves() (src/rewrite/AMMPair_Rewrite.sol#76-79)
	- AMMPair_Rewrite.reserve0 (src/rewrite/AMMPair_Rewrite.sol#34)
	- _update(balance0,balance1) (src/rewrite/AMMPair_Rewrite.sol#224)
		- reserve1 = uint112(balance1) (src/rewrite/AMMPair_Rewrite.sol#86)
	AMMPair_Rewrite.reserve1 (src/rewrite/AMMPair_Rewrite.sol#35) can be used in cross function reentrancies:
	- AMMPair_Rewrite._update(uint256,uint256) (src/rewrite/AMMPair_Rewrite.sol#81-87)
	- AMMPair_Rewrite.getReserves() (src/rewrite/AMMPair_Rewrite.sol#76-79)
	- AMMPair_Rewrite.reserve1 (src/rewrite/AMMPair_Rewrite.sol#35)
Reentrancy in AMMPair_Rewrite.swap(address,uint256,uint256,address) (src/rewrite/AMMPair_Rewrite.sol#229-283):
	External calls:
	- tIn = IERC20(tokenIn).transferFrom(msg.sender,address(this),amountIn) (src/rewrite/AMMPair_Rewrite.sol#245)
	- tOut = token1.transfer(to,amountOut) (src/rewrite/AMMPair_Rewrite.sol#262)
	- tOut = token0.transfer(to,amountOut) (src/rewrite/AMMPair_Rewrite.sol#271)
	State variables written after the call(s):
	- _update(balance0,balance1) (src/rewrite/AMMPair_Rewrite.sol#280)
		- reserve0 = uint112(balance0) (src/rewrite/AMMPair_Rewrite.sol#85)
	AMMPair_Rewrite.reserve0 (src/rewrite/AMMPair_Rewrite.sol#34) can be used in cross function reentrancies:
	- AMMPair_Rewrite._update(uint256,uint256) (src/rewrite/AMMPair_Rewrite.sol#81-87)
	- AMMPair_Rewrite.getReserves() (src/rewrite/AMMPair_Rewrite.sol#76-79)
	- AMMPair_Rewrite.reserve0 (src/rewrite/AMMPair_Rewrite.sol#34)
	- _update(balance0,balance1) (src/rewrite/AMMPair_Rewrite.sol#280)
		- reserve1 = uint112(balance1) (src/rewrite/AMMPair_Rewrite.sol#86)
	AMMPair_Rewrite.reserve1 (src/rewrite/AMMPair_Rewrite.sol#35) can be used in cross function reentrancies:
	- AMMPair_Rewrite._update(uint256,uint256) (src/rewrite/AMMPair_Rewrite.sol#81-87)
	- AMMPair_Rewrite.getReserves() (src/rewrite/AMMPair_Rewrite.sol#76-79)
	- AMMPair_Rewrite.reserve1 (src/rewrite/AMMPair_Rewrite.sol#35)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-1
INFO:Detectors:
LendingPool_Rewrite.borrowWithTwap(uint256) (src/rewrite/LendingPool_Rewrite.sol#187-213) ignores return value by (cumulative,None,timestamp) = oracle1.getCurrentCumulative() (src/rewrite/LendingPool_Rewrite.sol#191)
LendingPool_Rewrite.repay(uint256) (src/rewrite/LendingPool_Rewrite.sol#217-232) ignores return value by (cumulative,None,timestamp) = oracle1.getCurrentCumulative() (src/rewrite/LendingPool_Rewrite.sol#223)
LendingPool_Rewrite.withdrawCollateralWithTwap(uint256) (src/rewrite/LendingPool_Rewrite.sol#269-296) ignores return value by (cumulative,None,timestamp) = oracle1.getCurrentCumulative() (src/rewrite/LendingPool_Rewrite.sol#275)
LendingPool_Rewrite.getHealthFactorWithTwap(address) (src/rewrite/LendingPool_Rewrite.sol#320-341) ignores return value by (cumulative,None,timestamp) = oracle1.getCurrentCumulative() (src/rewrite/LendingPool_Rewrite.sol#333)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return
INFO:Detectors:
Reentrancy in AMMPair_Rewrite.addLiquidity(uint256,uint256,address) (src/rewrite/AMMPair_Rewrite.sol#150-189):
	External calls:
	- t0 = token0.transferFrom(msg.sender,address(this),token0Desired) (src/rewrite/AMMPair_Rewrite.sol#162)
	- t1 = token1.transferFrom(msg.sender,address(this),token1Desired) (src/rewrite/AMMPair_Rewrite.sol#163)
	State variables written after the call(s):
	- _mint(to,liquidity) (src/rewrite/AMMPair_Rewrite.sol#181)
		- balanceOf[to] += liquidity (src/rewrite/AMMPair_Rewrite.sol#112)
	- _update(balance0,balance1) (src/rewrite/AMMPair_Rewrite.sol#186)
		- reserve0 = uint112(balance0) (src/rewrite/AMMPair_Rewrite.sol#85)
	- _update(balance0,balance1) (src/rewrite/AMMPair_Rewrite.sol#186)
		- reserve1 = uint112(balance1) (src/rewrite/AMMPair_Rewrite.sol#86)
	- _mint(to,liquidity) (src/rewrite/AMMPair_Rewrite.sol#181)
		- totalSupply += liquidity (src/rewrite/AMMPair_Rewrite.sol#111)
Reentrancy in LendingPool_Rewrite.depositCollateral(uint256) (src/rewrite/LendingPool_Rewrite.sol#148-155):
	External calls:
	- ok = collateralToken.transferFrom(msg.sender,address(this),amount) (src/rewrite/LendingPool_Rewrite.sol#149)
	State variables written after the call(s):
	- collateralOf[msg.sender] += amount (src/rewrite/LendingPool_Rewrite.sol#152)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-2
INFO:Detectors:
Reentrancy in AMMPair_Rewrite.addLiquidity(uint256,uint256,address) (src/rewrite/AMMPair_Rewrite.sol#150-189):
	External calls:
	- t0 = token0.transferFrom(msg.sender,address(this),token0Desired) (src/rewrite/AMMPair_Rewrite.sol#162)
	- t1 = token1.transferFrom(msg.sender,address(this),token1Desired) (src/rewrite/AMMPair_Rewrite.sol#163)
	Event emitted after the call(s):
	- Mint(msg.sender,to,liquidity) (src/rewrite/AMMPair_Rewrite.sol#188)
Reentrancy in LendingPool_Rewrite.borrowWithSpot(uint256) (src/rewrite/LendingPool_Rewrite.sol#159-183):
	External calls:
	- ok = debtToken.transfer(msg.sender,amountDebt) (src/rewrite/LendingPool_Rewrite.sol#179)
	Event emitted after the call(s):
	- Borrow(msg.sender,amountDebt) (src/rewrite/LendingPool_Rewrite.sol#182)
Reentrancy in LendingPool_Rewrite.borrowWithTwap(uint256) (src/rewrite/LendingPool_Rewrite.sol#187-213):
	External calls:
	- ok = debtToken.transfer(msg.sender,amountDebt) (src/rewrite/LendingPool_Rewrite.sol#209)
	Event emitted after the call(s):
	- Borrow(msg.sender,amountDebt) (src/rewrite/LendingPool_Rewrite.sol#212)
Reentrancy in LendingPool_Rewrite.depositCollateral(uint256) (src/rewrite/LendingPool_Rewrite.sol#148-155):
	External calls:
	- ok = collateralToken.transferFrom(msg.sender,address(this),amount) (src/rewrite/LendingPool_Rewrite.sol#149)
	Event emitted after the call(s):
	- DepositCollateral(msg.sender,amount) (src/rewrite/LendingPool_Rewrite.sol#154)
Reentrancy in AMMPair_Rewrite.removeLiquidity(uint256,address) (src/rewrite/AMMPair_Rewrite.sol#191-227):
	External calls:
	- t0 = token0.transfer(to,amount0) (src/rewrite/AMMPair_Rewrite.sol#212)
	- t1 = token1.transfer(to,amount1) (src/rewrite/AMMPair_Rewrite.sol#213)
	Event emitted after the call(s):
	- Burn(msg.sender,to,liquidity) (src/rewrite/AMMPair_Rewrite.sol#226)
Reentrancy in LendingPool_Rewrite.repay(uint256) (src/rewrite/LendingPool_Rewrite.sol#217-232):
	External calls:
	- ok = debtToken.transferFrom(msg.sender,address(this),amountDebt) (src/rewrite/LendingPool_Rewrite.sol#228)
	Event emitted after the call(s):
	- Repay(msg.sender,amountDebt) (src/rewrite/LendingPool_Rewrite.sol#231)
Reentrancy in AMMPair_Rewrite.swap(address,uint256,uint256,address) (src/rewrite/AMMPair_Rewrite.sol#229-283):
	External calls:
	- tIn = IERC20(tokenIn).transferFrom(msg.sender,address(this),amountIn) (src/rewrite/AMMPair_Rewrite.sol#245)
	- tOut = token1.transfer(to,amountOut) (src/rewrite/AMMPair_Rewrite.sol#262)
	- tOut = token0.transfer(to,amountOut) (src/rewrite/AMMPair_Rewrite.sol#271)
	Event emitted after the call(s):
	- Swap(msg.sender,to,tokenIn,amountIn,amountOut) (src/rewrite/AMMPair_Rewrite.sol#282)
Reentrancy in LendingPool_Rewrite.withdrawCollateralWithSpot(uint256) (src/rewrite/LendingPool_Rewrite.sol#236-267):
	External calls:
	- okFree = collateralToken.transfer(msg.sender,amount) (src/rewrite/LendingPool_Rewrite.sol#245)
	Event emitted after the call(s):
	- WithdrawCollateral(msg.sender,amount) (src/rewrite/LendingPool_Rewrite.sol#248)
Reentrancy in LendingPool_Rewrite.withdrawCollateralWithSpot(uint256) (src/rewrite/LendingPool_Rewrite.sol#236-267):
	External calls:
	- ok = collateralToken.transfer(msg.sender,amount) (src/rewrite/LendingPool_Rewrite.sol#263)
	Event emitted after the call(s):
	- WithdrawCollateral(msg.sender,amount) (src/rewrite/LendingPool_Rewrite.sol#266)
Reentrancy in LendingPool_Rewrite.withdrawCollateralWithTwap(uint256) (src/rewrite/LendingPool_Rewrite.sol#269-296):
	External calls:
	- ok = collateralToken.transfer(msg.sender,amount) (src/rewrite/LendingPool_Rewrite.sol#292)
	Event emitted after the call(s):
	- WithdrawCollateral(msg.sender,amount) (src/rewrite/LendingPool_Rewrite.sol#295)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3
INFO:Detectors:
SpotOracle_Rewrite.getPrice0() (src/rewrite/SpotOracle_Rewrite.sol#60-65) uses timestamp for comparisons
	Dangerous comparisons:
	- lastUpdateAt == 0 (src/rewrite/SpotOracle_Rewrite.sol#61)
SpotOracle_Rewrite.getPrice1() (src/rewrite/SpotOracle_Rewrite.sol#67-72) uses timestamp for comparisons
	Dangerous comparisons:
	- lastUpdateAt == 0 (src/rewrite/SpotOracle_Rewrite.sol#68)
TwapOracle_Rewrite.update() (src/rewrite/TwapOracle_Rewrite.sol#58-80) uses timestamp for comparisons
	Dangerous comparisons:
	- lastUpdateAt != 0 (src/rewrite/TwapOracle_Rewrite.sol#65)
	- timeElapsed > 0 (src/rewrite/TwapOracle_Rewrite.sol#67)
TwapOracle_Rewrite.getCurrentCumulative() (src/rewrite/TwapOracle_Rewrite.sol#82-100) uses timestamp for comparisons
	Dangerous comparisons:
	- lastUpdateAt == 0 (src/rewrite/TwapOracle_Rewrite.sol#87)
	- timeElapsed > 0 (src/rewrite/TwapOracle_Rewrite.sol#96)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#block-timestamp
INFO:Detectors:
AMMPair_Rewrite (src/rewrite/AMMPair_Rewrite.sol#10-285) should inherit from IAMMPair (src/rewrite/SpotOracle_Rewrite.sol#4-6)
SpotOracle_Rewrite (src/rewrite/SpotOracle_Rewrite.sol#8-74) should inherit from ISpotOracle (src/rewrite/LendingPool_Rewrite.sol#16-19)
TwapOracle_Rewrite (src/rewrite/TwapOracle_Rewrite.sol#8-102) should inherit from ITwapOracle (src/rewrite/LendingPool_Rewrite.sol#9-14)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#missing-inheritance
INFO:Detectors:
Contract AMMPair_Rewrite (src/rewrite/AMMPair_Rewrite.sol#10-285) is not in CapWords
Contract LendingPool_Rewrite (src/rewrite/LendingPool_Rewrite.sol#21-343) is not in CapWords
Contract SpotOracle_Rewrite (src/rewrite/SpotOracle_Rewrite.sol#8-74) is not in CapWords
Contract TwapOracle_Rewrite (src/rewrite/TwapOracle_Rewrite.sol#8-102) is not in CapWords
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#conformance-to-solidity-naming-conventions
INFO:Slither:. analyzed (19 contracts with 100 detectors), 40 result(s) found
duobtc@duodemac-mini AMM-Oracle % 

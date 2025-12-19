// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns(bool);
    function transferFrom(address from, address to, uint256 amount) external returns(bool);
}

interface ITwapOracle {
    function getCurrentCumulative()
        external
        view
        returns(uint256 cumulative0, uint256 cumulative1, uint256 timestamp);
}

interface ISpotOracle {
    /// @notice The spot price of token0 in terms of token1.
    function getPrice0() external view returns(uint256 price0);
}

contract LendingPool_Rewrite {
    /// @notice The address represented as token0 in the AMMPair.
    IERC20 public immutable collateralToken;
    /// @notice The address of token1 in the AMMPair.
    IERC20 public immutable debtToken;

    /// @notice The SpotOracle address.
    ISpotOracle public immutable oracle0;
    /// @notice This address is existed as the TwapOracle.
    ITwapOracle public immutable oracle1;

    /// @notice The recorded token0 balance of the user.
    mapping(address => uint256) public collateralOf;

    /// @notice The recorded token1 balance of the user.
    mapping(address => uint256) public debtOf;

    /// @notice Last recorded cumulative of collateralToken.
    uint256 public lastCumulative;
    /// @notice Last update timestamp.
    uint256 public lastUpdateTime;

    /// @notice Loan-to-value ratio as 50%
    uint256 public constant LTV = 5e17;
    /// @notice liquidation threshold ratio as 80%
    uint256 public constant LIQ_THRESHOLD = 8e17;

    // --- Custom Errors --- //
    error ZeroAddress();
    error InvalidAddress();
    error RepeatedAddress();
    error ZeroAmount();
    error OraclePriceZero();
    error NoCollateral();
    error TransferFailed();
    error TwapNotUpdate();
    error ExceedsLTV();
    error InsufficientCollateral();
    error BadHealthFactor();

    // --- Events --- //
    event DepositCollateral(address indexed user, uint256 amount);
    event WithdrawCollateral(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amountDebt);

    /// @param _collateralToken The address of token0
    /// @param _debtToken The address of token1
    /// @param _oracle0 The address of the SpotOracle
    /// @param _oracle1 The address of the TwapOracle
    constructor(
        address _collateralToken,
        address _debtToken,
        address _oracle0,
        address _oracle1
    ) {
        if(_collateralToken == address(0)
            || _debtToken == address(0)
            || _oracle0 == address(0)
            || _oracle1 == address(0)
        ) {
            revert ZeroAddress();
        }
        if(_collateralToken.code.length == 0
            || _debtToken.code.length == 0
            || _oracle0.code.length == 0
            || _oracle1.code.length == 0
        ) {
            revert InvalidAddress();
        }
        if(_collateralToken == _debtToken) {
            revert RepeatedAddress();
        }
        collateralToken = IERC20(_collateralToken);
        debtToken = IERC20(_debtToken);
        oracle0 = ISpotOracle(_oracle0);
        oracle1 = ITwapOracle(_oracle1);
    }

    modifier notZero(uint256 amount) {
        if(amount == 0) {
            revert ZeroAmount();
        }
        _;
    }

    // --- Helper Functions --- //
    function _validPrice(uint256 price) private pure {
        if(price == 0) {
            revert OraclePriceZero();
        }
    }

    function _validColl(uint256 _collateral) private pure {
        if(_collateral == 0) {
            revert NoCollateral();
        }
    }

    function _validTransfer(bool ok) private pure {
        if(!ok) {
            revert TransferFailed();
        }
    }

    function _computeTwapPrice(uint256 cum, uint256 elapse) private pure returns(uint256) {
        if(cum > 0 && elapse > 0) {
            return cum * 1e18 / elapse;
        } else {
            return 0;
        }
    }

    function _computeTwapElapse(
        uint256 cumulative,
        uint256 timestamp
    ) private view returns(uint256 cum, uint256 elapse) {
        if(lastCumulative >= cumulative || lastUpdateTime >= timestamp) {
            revert TwapNotUpdate();
        }
        cum = cumulative - lastCumulative;
        elapse = timestamp - lastUpdateTime;
    }

    // --- Core Functions --- //
    /// @notice Deposits the user's collateral.
    /// @param amount Amount of collateral tokens to deposit in the collateral token's smallest units.
    function depositCollateral(uint256 amount) external notZero(amount) {
        bool ok = collateralToken.transferFrom(msg.sender, address(this), amount);
        _validTransfer(ok);

        collateralOf[msg.sender] += amount;

        emit DepositCollateral(msg.sender, amount);
    }

    /// @notice Borrows debt tokens using the collateral's spot price for quoting.
    /// @param amountDebt Amount of debt tokens to borrow in the debt token's smallest units.
    function borrowWithSpot(uint256 amountDebt) external notZero(amountDebt) {
        uint256 coll = collateralOf[msg.sender];
        _validColl(coll);

        uint256 price = oracle0.getPrice0();
        _validPrice(price);

        uint256 collValue = coll * price / 1e18;

        uint256 maxEarn = collValue * LTV / 1e18;

        uint256 debt = debtOf[msg.sender];

        uint256 newDebt = debt + amountDebt;
        if(newDebt > maxEarn) {
            revert ExceedsLTV();
        }

        debtOf[msg.sender] = newDebt;

        bool ok = debtToken.transfer(msg.sender, amountDebt);
        _validTransfer(ok);

        emit Borrow(msg.sender, amountDebt);
    }

    /// @notice Borrows debt tokens using the collateral's TWAP price for quoting.
    /// @param amountDebt Amount of debt tokens to borrow in the debt token's smallest units.
    function borrowWithTwap(uint256 amountDebt) external notZero(amountDebt) {
        uint256 coll = collateralOf[msg.sender];
        _validColl(coll);

        (uint256 cumulative, , uint256 timestamp) = oracle1.getCurrentCumulative();
        (uint256 cum, uint256 elapse) = _computeTwapElapse(cumulative, timestamp);
        uint256 price = _computeTwapPrice(cum, elapse);
        _validPrice(price);

        uint256 collValue = coll * price / 1e18;

        uint256 maxEarn = collValue * LTV / 1e18;

        uint256 newDebt = debtOf[msg.sender] + amountDebt;
        if(newDebt > maxEarn) {
            revert ExceedsLTV();
        }

        debtOf[msg.sender] = newDebt;
        lastCumulative = cumulative;
        lastUpdateTime = timestamp;

        bool ok = debtToken.transfer(msg.sender, amountDebt);
        _validTransfer(ok);

        emit Borrow(msg.sender, amountDebt);
    }
    
    /// @notice Repay debt tokens.
    /// @param amountDebt Amount of debt tokens to repay in the debt token's smallest units.
    function repay(uint256 amountDebt) external notZero(amountDebt) {
        uint256 debt = debtOf[msg.sender];
        if(amountDebt > debt) {
            amountDebt = debt;
        }

        (uint256 cumulative, , uint256 timestamp) = oracle1.getCurrentCumulative();
        lastCumulative = cumulative;
        lastUpdateTime = timestamp;
        debtOf[msg.sender] = debt - amountDebt;

        bool ok = debtToken.transferFrom(msg.sender, address(this), amountDebt);
        _validTransfer(ok);

        emit Repay(msg.sender, amountDebt);
    }

    /// @notice Withdraw collateral tokens using the collateral's spot price.
    /// @param amount Amount of the collateral token to withdraw in the collateral's smallest units.
    function withdrawCollateralWithSpot(uint256 amount) external notZero(amount) {
        uint256 coll = collateralOf[msg.sender];
        if(amount > coll) {
            revert InsufficientCollateral();
        }

        uint256 debt = debtOf[msg.sender];
        if(debt == 0) {
            collateralOf[msg.sender] -= amount;
            bool okFree = collateralToken.transfer(msg.sender, amount);
            _validTransfer(okFree);

            emit WithdrawCollateral(msg.sender, amount);
            return;
        }

        uint256 price = oracle0.getPrice0();
        _validPrice(price);

        uint256 newColl = coll - amount;
        uint256 newCollValue = newColl * price / 1e18;
        if(debt * 1e18 > newCollValue * LIQ_THRESHOLD) {
            revert BadHealthFactor();
        }

        collateralOf[msg.sender] = newColl;

        bool ok = collateralToken.transfer(msg.sender, amount);
        _validTransfer(ok);

        emit WithdrawCollateral(msg.sender, amount);
    }

    function withdrawCollateralWithTwap(uint256 amount) external notZero(amount) {
        uint256 coll = collateralOf[msg.sender];
        if(amount > coll) {
            revert InsufficientCollateral();
        }

        (uint256 cumulative, , uint256 timestamp) = oracle1.getCurrentCumulative();
        (uint256 cum, uint256 elapse) = _computeTwapElapse(cumulative, timestamp);
        uint256 price = _computeTwapPrice(cum, elapse);
        _validPrice(price);

        uint256 newColl = coll - amount;
        uint256 newCollValue = newColl * price / 1e18;

        uint256 debt = debtOf[msg.sender];
        if(debt * 1e18 > newCollValue * LIQ_THRESHOLD) {
            revert BadHealthFactor();
        }

        lastCumulative = cumulative;
        lastUpdateTime = timestamp;
        collateralOf[msg.sender] = newColl;

        bool ok = collateralToken.transfer(msg.sender, amount);
        _validTransfer(ok);

        emit WithdrawCollateral(msg.sender, amount);
    }


    function getHealthFactorWithSpot(address user) external view returns(uint256) {
        if(user == address(0)) {
            revert ZeroAddress();
        }

        uint256 debt = debtOf[user];
        if(debt == 0) {
            return type(uint256).max;
        }

        uint256 price = oracle0.getPrice0();
        _validPrice(price);

        uint256 coll = collateralOf[user];
        _validColl(coll);

        uint256 collValue = coll * price / 1e18;

        return collValue * LIQ_THRESHOLD / debt / 1e18;
    }

    function getHealthFactorWithTwap(address user) external view returns(uint256) {
        if(user == address(0)) {
            revert ZeroAddress();
        }

        uint256 debt = debtOf[user];
        if(debt == 0) {
            return type(uint256).max;
        }

        uint256 coll = collateralOf[user];
        _validColl(coll);

        (uint256 cumulative, , uint256 timestamp) = oracle1.getCurrentCumulative();
        (uint256 cum, uint256 elapse) = _computeTwapElapse(cumulative, timestamp);
        uint256 price = _computeTwapPrice(cum, elapse);
        _validPrice(price);

        uint256 collValue = coll * price / 1e18;

        return collValue * LIQ_THRESHOLD / debt / 1e18;
    }
}
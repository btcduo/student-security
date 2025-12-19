// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns(bool);
    function transferFrom(address from, address to, uint256 amount) external returns(bool);
}

interface ITWAPOracle {
    function getCurrenCumulative()
        external
        view
        returns(uint256 cumulative0, uint256 cumulative1, uint256 timestamp);
}

interface IPriceOracle {
    function getPrice0() external view returns(uint256 spotPrice0);
}

contract LendingPool {
    /// @notice A single asset existed as token0 in AMMPair contract.
    IERC20 public immutable collateralToken;
    /// @notice A single asset existed as token1 in AMMPair contract.
    IERC20 public immutable debtToken;
    /// @notice The address of SpotOracle.
    IPriceOracle public immutable oracle0;
    /// @notice The address of TwapOracle.
    ITWAPOracle public immutable oracle1;

    /// @notice Loan-to-value ratio as 50%
    uint256 public constant LTV = 5e17;

    /// @notice Liquidation threshold as 80%
    uint256 public constant LIQ_THRESHOLD = 8e17;

    /// @notice User collateral amount (in collateralToken units)
    mapping(address => uint256) public collateralOf;

    /// @notice User Debt amount (in debtToken units)
    mapping(address => uint256) public debtOf;

    error ZeroAddress();
    error NotContract();
    error RepeatedAssets();
    error ZeroAmount();
    error TransferFailed();
    error ExceedsLtv();
    error InsufficientCollateral();
    error InvalidHealthFactor();
    error OraclePriceZero();

    event DepositCollateral(address indexed user, uint256 amount);
    event WithdrawCollateral(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amountDebt);
    event Repay(address indexed user, uint256 amountDebt);

    constructor(address _collateralToken, address _debtToken, address _oracle0, address _oracle1) {
        if(_isZero(_collateralToken) || _isZero(_debtToken) || _isZero(_oracle0) || _isZero(_oracle1)) {
            revert ZeroAddress();
        }
        if(_notCa(_collateralToken) || _notCa(_debtToken) || _notCa(_oracle0) || _notCa(_oracle1)) {
            revert NotContract();
        }
        if(_collateralToken == _debtToken) {
            revert RepeatedAssets();
        }
        collateralToken = IERC20(_collateralToken);
        debtToken = IERC20(_debtToken);
        oracle0 = IPriceOracle(_oracle0);
        oracle1 = ITWAPOracle(_oracle1);
    }

    function _isZero(address addr) private pure returns(bool) {
        if(addr == address(0)) {
            return true;
        }
        return false;
    }

    function _notCa(address addr) private view returns(bool) {
        if(addr.code.length == 0) {
            return true;
        }
        return false;
    }

    function depositCollateral(uint256 amount) external {
        if(amount == 0) {
            revert ZeroAmount();
        }

        bool ok = collateralToken.transferFrom(msg.sender, address(this), amount);
        if(!ok) {
            revert TransferFailed();
        }

        collateralOf[msg.sender] += amount;
        emit DepositCollateral(msg.sender, amount);
    }

    function borrowWithSpot(uint256 amountDebt) external {
        if(amountDebt == 0) {
            revert ZeroAmount();
        }

        uint256 price = oracle0.getPrice0();
        if(price == 0) {
            revert OraclePriceZero();
        }

        uint256 collateralAmount = collateralOf[msg.sender];
        if(collateralAmount == 0) {
            revert InsufficientCollateral();
        }

        uint256 collateralValue = collateralAmount * price / 1e18;

        uint256 maxDebt = collateralValue * LTV / 1e18;

        uint256 newDebt = debtOf[msg.sender] + amountDebt;
        if(maxDebt > newDebt) {
            revert ExceedsLtv();
        }

        debtOf[msg.sender] = newDebt;

        bool ok = debtToken.transfer(msg.sender, amountDebt);
        if(!ok) {
            revert TransferFailed();
        }
        
        emit Borrow(msg.sender, amountDebt);
    }

    function repay(uint256 amountDebt) external {
        if(amountDebt == 0) {
            revert ZeroAmount();
        }

        uint256 currentDebt = debtOf[msg.sender];
        if(currentDebt == 0) {
            return;
        }

        uint256 toRepay = amountDebt < currentDebt ? amountDebt : currentDebt;

        bool ok = debtToken.transferFrom(msg.sender, address(this), toRepay);
        if(!ok) {
            revert TransferFailed();
        }

        debtOf[msg.sender] = currentDebt - toRepay;

        emit Repay(msg.sender, amountDebt);
    }

    function withdrawCollateral(uint256 amount) external {
        if(amount == 0) {
            revert ZeroAmount();
        }
        
        uint256 coll = collateralOf[msg.sender];
        if(amount > coll) {
            revert InsufficientCollateral();
        }

        uint256 debt = debtOf[msg.sender];

        if(debt == 0) {
            collateralOf[msg.sender] = coll - amount;

            bool okFree = collateralToken.transfer(msg.sender, amount);
            if(!okFree) {
                revert TransferFailed();
            }

            emit WithdrawCollateral(msg.sender, amount);
            return;
        }

        uint256 price = oracle0.getPrice0();
        if(price == 0) {
            revert OraclePriceZero();
        }

        uint256 newColl = coll - amount;

        uint256 newCollValue = newColl * price / 1e18;
        if(debt * 1e18 > newCollValue * LIQ_THRESHOLD) {
            revert InvalidHealthFactor();
        }

        collateralOf[msg.sender] = newColl;

        bool ok = collateralToken.transfer(msg.sender, amount);
        if(!ok) {
            revert TransferFailed();
        }

        emit WithdrawCollateral(msg.sender, amount);
    }

    function getHealthFactor(address user) external view returns(uint256) {
        if(_isZero(user)) {
            revert ZeroAddress();
        }

        uint256 debt = debtOf[user];
        if(debt == 0) {
            return type(uint256).max;
        }

        uint256 price = oracle0.getPrice0();
        if(price == 0) {
            revert OraclePriceZero();
        }

        uint256 coll = collateralOf[user];
        uint256 collValue = coll * price / 1e18;

        return collValue * LIQ_THRESHOLD / debt / 1e18;
    }
}
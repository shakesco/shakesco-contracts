// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../Shakesco/PriceConverter.sol";
import "./Account.sol";

error SAVING__TRANSACTIONFAILED();
error SAVING__NOTOWNER();
error SAVING__TARGETNOTMET();
error SAVINGS__ONLYEXECUTE();
error SAVINGS__CANNOTRESET();

/// @title Savings Account
/// @author Shawn Kimtai
/// @notice This will allow you to save money without any custodial service.
/// @dev This is one of the contracts that will be owned by account contract
/// @dev owner. To avoid handling funds we allow users to lock up their funds
/// @dev for the specified time until time ends and they reach the intended amount.
/// @dev In that period they can receive funds in their savings account if selected
/// @dev randomly by the chainlink vrf coordinator. See FromShakespay.sol
/// @dev On sending funds to the this contract they also call a function to be added
/// @dev to the 'Raffle' and hence start to participate.

using PriceConverter for uint256;

contract ShakescoSavings is UUPSUpgradeable, Initializable {
    //Amount they will need to reach so as to withdraw
    uint256 private s_amountToReach;
    //Time period for saving
    uint256 private s_timePeriod;
    //Last timestamp saved
    uint256 private s_lastTimeStamp;
    //Their account contract which will call these functions
    ShakescoAccount account;
    //Able to reset after withdrawal
    bool private s_canreset;

    //events
    event FundsMoved(
        address indexed to,
        uint256 indexed amount,
        address indexed from
    );
    event SavingsInitilized(address indexed owner);

    /// @dev only account can call these functions
    modifier onlyOwner() {
        if (msg.sender != address(account)) {
            revert SAVING__NOTOWNER();
        }
        _;
    }

    /// @dev only reset after withdrawal
    modifier _canReset() {
        if (!s_canreset) {
            revert SAVINGS__CANNOTRESET();
        }
        _;
    }

    ///  @dev Disable future reinitialization that may cause attackers
    ///       to exploit that vulnerability
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes implementation for contract
     * @param accountAddress Account address. Can also be owner.
     * @param amountToReach Limit of saving
     * @param timePeriod Limit time of saving
     */
    function initialize(
        address payable accountAddress,
        uint256 amountToReach,
        uint256 timePeriod
    ) public virtual initializer {
        _initialize(accountAddress, amountToReach, timePeriod);
    }

    function _initialize(
        address payable accountAddress,
        uint256 amountToReach,
        uint256 timePeriod
    ) internal virtual {
        account = ShakescoAccount(accountAddress);
        s_amountToReach = amountToReach;
        s_canreset = false;
        s_lastTimeStamp = block.timestamp;
        s_timePeriod = timePeriod;
        emit SavingsInitilized(accountAddress);
    }

    receive() external payable {}

    /**
     * @dev The below function will allow the user to remove funds from saving to the Account.
     * @dev Only the account owner(In the Account contract) should call this function.
     * @param _amount is the amount the account owner wants to send to the Account.
     * @param nativepriceAddress Price feed address of these chain
     */

    //take 1% if money doubles.
    function sendToAccount(
        uint256 _amount,
        address nativepriceAddress
    ) external onlyOwner {
        AggregatorV3Interface nativepricefeed = AggregatorV3Interface(
            nativepriceAddress
        );
        uint nativeBalance = address(this).balance.getConvertionRate(
            nativepricefeed
        );

        bool checkTime = true;

        if (!s_canreset) {
            if (nativeBalance < s_amountToReach) {
                revert SAVING__TARGETNOTMET();
            }

            checkTime = false;
        }

        if (s_canreset) checkTime = false;

        //Check if they have reached the amount set and time period has elapsed
        if ((block.timestamp - s_lastTimeStamp) < s_timePeriod && checkTime) {
            revert SAVING__TARGETNOTMET();
        }

        //They can now reset and set new conditions for saving
        s_canreset = true;

        (bool success, ) = payable(address(account)).call{value: _amount}("");

        if (!success) {
            revert SAVING__TRANSACTIONFAILED();
        }

        emit FundsMoved(address(account), _amount, address(this));
    }

    /**
     * @dev After withdrawing they can set new conditions for saving
     * @param newPeriod The new time period for saving
     * @param newAmount The new amount to reach
     */
    function resetTime(
        uint256 newPeriod,
        uint256 newAmount
    ) external payable onlyOwner _canReset {
        s_timePeriod = newPeriod;
        s_lastTimeStamp = block.timestamp;
        s_amountToReach = newAmount;
        s_canreset = false;
    }

    /// @dev New implementation of this contract. User can choose to
    /// implement it or not.
    function _authorizeUpgrade(
        address newImplementation
    ) internal view override onlyOwner {
        (newImplementation);
    }

    /////////////////////////////////////////
    /////////////GET FUNCTIONS//////////////
    ///////////////////////////////////////

    function getTimePeriod() external view returns (uint256) {
        return s_timePeriod;
    }

    function getAmountSet() external view returns (uint256) {
        return s_amountToReach;
    }

    function canResetAndWithdraw() external view returns (bool) {
        return s_canreset;
    }
}

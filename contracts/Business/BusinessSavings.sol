// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../Shakesco/PriceConverter.sol";
import "./BusinessContract.sol";

error BUSINESSSAVING__NOTENOUGHFUNDS();
error BUSINESSSAVING__TRANSACTIONFAILED();
error BUSINESSSAVING__NOTOWNER();
error BUSINESSSAVING__TARGETNOTMET();
error BUSINESSSAVINGS__CANNOTRESET();

/// @title Savings Account
/// @author Shawn Kimtai
/// @dev Works similar to account saving. And is owned by business
/// @dev account.

using PriceConverter for uint256;

contract ShakescoBusinessSavings is UUPSUpgradeable, Initializable {
    uint256 private s_amountToReach;
    uint256 private s_timePeriod;
    uint256 private s_lastTimeStamp;
    bool private s_canreset;
    ShakescoBusinessContract businessAccount;

    //events
    event FundsMoved(
        address indexed to,
        uint256 indexed amount,
        address indexed from
    );
    event BusinessSavingsInitilized(address indexed owner);

    modifier onlyOwner() {
        if (msg.sender != address(businessAccount)) {
            revert BUSINESSSAVING__NOTOWNER();
        }
        _;
    }

    modifier _canReset() {
        if (!s_canreset) {
            revert BUSINESSSAVINGS__CANNOTRESET();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes implementation for contract
     * @param businessAddress Account address. Can also be owner.
     * @param amountToReach Limit of saving
     * @param timePeriod Limit time of saving
     */

    function initialize(
        address payable businessAddress,
        uint256 amountToReach,
        uint256 timePeriod
    ) public virtual initializer {
        _initialize(businessAddress, amountToReach, timePeriod);
    }

    function _initialize(
        address payable businessAddress,
        uint256 amountToReach,
        uint256 timePeriod
    ) internal virtual {
        businessAccount = ShakescoBusinessContract(businessAddress);
        s_lastTimeStamp = block.timestamp;
        s_canreset = false;
        s_amountToReach = amountToReach;
        s_timePeriod = timePeriod;
        emit BusinessSavingsInitilized(businessAddress);
    }

    receive() external payable {}

    /**
     * @dev The below function will allow the business to remove funds from saving to the business.
     * @dev Only the business owner(In the Business contract) should call this function.
     * @param amount is the amount the business owner wants to send to the Account.
     * @param nativepriceAddress Price feed address of these chain
     */

    function sendToBusiness(
        uint256 amount,
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
                revert BUSINESSSAVING__TARGETNOTMET();
            }
            checkTime = false;
        }

        if (s_canreset) checkTime = false;

        if ((block.timestamp - s_lastTimeStamp) < s_timePeriod && checkTime) {
            revert BUSINESSSAVING__TARGETNOTMET();
        }

        s_canreset = true;

        (bool success, ) = payable(address(businessAccount)).call{
            value: amount
        }("");

        if (!success) {
            revert BUSINESSSAVING__TRANSACTIONFAILED();
        }

        emit FundsMoved(address(businessAccount), amount, address(this));
    }

    /**
     * @dev After withdrawing they can set new conditions for saving
     * @param newPeriod The new time period for saving
     * @param newAmount The new amount to reach
     */
    function resetTime(
        uint256 newPeriod,
        uint256 newAmount
    ) external onlyOwner _canReset {
        s_timePeriod = newPeriod;
        s_lastTimeStamp = block.timestamp;
        s_canreset = false;
        s_amountToReach = newAmount;
    }

    /// @dev Authorize new upgrade
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

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
    //Amount they will need to reach so as to withdraw
    uint256 private s_amountToReach;
    //Time period for saving
    uint256 private s_timePeriod;
    //Last timestamp saved
    uint256 private s_lastTimeStamp;
    //Able to reset after withdrawal
    bool private s_canreset;
    //Their account contract which will call these functions
    ShakescoBusinessContract businessAccount;
    //Price feed(Mapping of address to price feed)
    mapping(address => address) private s_priceFeedAddresses;
    //addresss of tokens supported
    address[] private s_supportedTokens;

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
        address nativepriceAddress,
        address withdrawToken,
        bool urgent
    ) external onlyOwner {
        if (!urgent) {
            AggregatorV3Interface nativepricefeed = AggregatorV3Interface(
                nativepriceAddress
            );
            uint nativeBalance = address(this).balance.getConvertionRate(
                nativepricefeed
            );

            uint len = s_supportedTokens.length;

            for (uint i = 0; i < len; ) {
                address tokenAddress = s_supportedTokens[i];
                address feedAddress = s_priceFeedAddresses[tokenAddress];
                AggregatorV3Interface tokenpricefeed = AggregatorV3Interface(
                    feedAddress
                );
                uint bal = IERC20(tokenAddress).balanceOf(address(this));
                nativeBalance += bal.getConvertionRate(tokenpricefeed);
                unchecked {
                    ++i;
                }
            }

            bool checkTime = true;

            if (!s_canreset) {
                if (nativeBalance < s_amountToReach) {
                    revert BUSINESSSAVING__TARGETNOTMET();
                }
                checkTime = false;
            }

            if (s_canreset) checkTime = false;

            if (
                (block.timestamp - s_lastTimeStamp) < s_timePeriod && checkTime
            ) {
                revert BUSINESSSAVING__TARGETNOTMET();
            }
        }

        if (!s_canreset) {
            s_canreset = true;
        }

        if (withdrawToken != address(0)) {
            bool success = IERC20(withdrawToken).transfer(
                address(businessAccount),
                amount
            );

            if (!success) {
                revert BUSINESSSAVING__TRANSACTIONFAILED();
            }
        } else {
            (bool success, ) = payable(address(businessAccount)).call{
                value: amount
            }("");

            if (!success) {
                revert BUSINESSSAVING__TRANSACTIONFAILED();
            }
        }

        emit FundsMoved(address(businessAccount), amount, address(this));
    }

    /**
     * This function is called when a business whats to add a token address to the assets they are saving
     * @param token Token address
     * @param priceFeed Price feed address of the token
     */

    function addSupportedTokens(
        address[] calldata token,
        address[] calldata priceFeed
    ) external onlyOwner {
        uint len = token.length;
        for (uint i = 0; i < len; ) {
            addToken(token[i]);
            s_priceFeedAddresses[token[i]] = priceFeed[i];
            unchecked {
                ++i;
            }
        }
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

    function priceFeedOfToken(address token) external view returns (address) {
        return s_priceFeedAddresses[token];
    }

    function supportedTokens() external view returns (address[] memory) {
        return s_supportedTokens;
    }

    function version() external pure returns (uint) {
        return 2;
    }

    function addToken(address token) private {
        bool found = false;
        uint len = s_supportedTokens.length;
        for (uint i = 0; i < len; ) {
            if (s_supportedTokens[i] == token) {
                found = true;
                break;
            }
            if (!found && i == (s_supportedTokens.length - 1)) {
                s_supportedTokens.push(token);
            }
            unchecked {
                ++i;
            }
        }

        if (s_supportedTokens.length == 0) {
            s_supportedTokens.push(token);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../Shakesco/PriceConverter.sol";

error BUSINESSCONTRACT__NOTOWNER();
error BUSINESSCONTRACT__TRANSACTIONFAILED();
error BUSINESSCONTRACT__NOTOWNERORENTRYPOINT();
error BUSINESSCONTRACT__INVALIDLENGTH();

/// @title Smart Wallet(Business)
/// @author Shawn Kimtai
/// @dev This contract works similar to how account works
/// @dev Only difference is 2 functions(Employee functions).

using ECDSA for bytes32;
using PriceConverter for uint256;

contract ShakescoBusinessContract is
    IERC721Receiver,
    ReentrancyGuard,
    BaseAccount,
    UUPSUpgradeable,
    Initializable
{
    //Maps every payer to this business so that they can get reward
    //tokens if they spend up to s_supposedToSpendForTokens
    mapping(address => uint256) private s_spendingOnBusinessForTokens;
    //Limit to spending to get reward tokens
    uint256 private s_supposedToSpendForTokens;
    //PAyment to saving on receiving native token
    uint256 private s_autoSavingPercent;
    //Payment to employee directly instead of business
    uint256 private s_percentToEmployee;
    //Owner of business
    address private businessOwner;
    //Business saving account
    address payable private businessSaving;
    //Business token account
    address private s_businessTokenAddress;
    //Business nft/sbt account
    address private s_businessNFTAddress;
    //is business willing to autosave
    bool private s_canAutoSave;
    //is business willing to allow pay to employee directly
    bool private s_canSendToEmployee;
    //Entrypoint for calling functions on behalf of owner
    IEntryPoint private immutable s_entryPoint;
    //spending for airdrop
    mapping(address => uint256) private s_spendingOnBusinessForDrop;

    event FundsMoved(
        address indexed to,
        uint256 indexed amount,
        bytes indexed func
    );
    event BusinessInitialized(
        address indexed _entryPoint,
        address indexed owner
    );

    /// @dev checks if contract owner called functions with this access modifier
    modifier onlyOwner() {
        if (msg.sender != address(this)) {
            revert BUSINESSCONTRACT__NOTOWNER();
        }
        _;
    }

    /// @dev checks if functions with this access modifier were called by entrypoint
    modifier onlyEntryPoint() {
        if (msg.sender != address(s_entryPoint)) {
            revert BUSINESSCONTRACT__NOTOWNERORENTRYPOINT();
        }
        _;
    }

    constructor(address _entryPoint) {
        s_entryPoint = IEntryPoint(_entryPoint);
        _disableInitializers();
    }

    /**
     * @notice Initializes implementation for contract
     * @param accountOwner Sets owner of contract
     */
    function initialize(address accountOwner) public virtual initializer {
        _initialize(accountOwner);
    }

    function _initialize(address owner) internal virtual {
        businessOwner = owner;
        emit BusinessInitialized(address(s_entryPoint), businessOwner);
    }

    receive() external payable {}

    /**
     * @notice Execute an operation
     * @param _to is supposed to send money to the address entered
     * @param _amount The amount to call execute with
     * @param func Is the function to be executed
     */

    function execute(
        address payable _to,
        uint _amount,
        bytes calldata func
    ) external onlyEntryPoint {
        _call(_to, _amount, func);
    }

    /**
     * @notice Execute a bunch of operation
     * @param _to is supposed to send money to the address entered
     * @param _amount The amount to call execute with
     * @param func Is the function to be executed
     */

    function executeBatch(
        address payable[] calldata _to,
        uint256[] calldata _amount,
        bytes[] calldata func
    ) external onlyEntryPoint {
        if (
            _to.length != func.length &&
            (_amount.length != 0 || _amount.length != func.length)
        ) {
            revert BUSINESSCONTRACT__INVALIDLENGTH();
        }
        if (_amount.length == 0) {
            for (uint256 i = 0; i < _to.length; i++) {
                _call(_to[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < _to.length; i++) {
                _call(_to[i], _amount[i], func[i]);
            }
        }
    }

    /**
     * @dev The function below is called when the 'to' in safe transfer above is
     * a contract.
     * @dev If so it calls the below function on the 'to'.
     */

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @dev The following function will help users to set their savings address for
     * autosaving.
     * @param mySavingsAddress The address the user has received as their address
     * @param percent The percent the business wants to autosave with every native asset credit.
     */

    function setSavingsAddress(
        address payable mySavingsAddress,
        uint256 percent
    ) external onlyOwner {
        if (percent > 100) {
            revert BUSINESSCONTRACT__TRANSACTIONFAILED();
        }

        businessSaving = mySavingsAddress;
        s_autoSavingPercent = percent;
        s_canAutoSave = percent > 0 ? true : false;
    }

    /**
     * @dev The following function sets autoSaving to true.
     * @param percent The percent the business wants to autosave with every native asset credit.
     */

    function setAutoSaving(uint256 percent) external onlyOwner {
        if (percent > 100) {
            revert BUSINESSCONTRACT__TRANSACTIONFAILED();
        }

        s_autoSavingPercent = percent;
        s_canAutoSave = true;
    }

    /**
     * @dev The following function removes autoSaving.
     */

    function removeAutoSaving() external onlyOwner {
        s_canAutoSave = false;
    }

    /**
     * @dev The following function will help users to auto save when they receive
     * ether or token
     * @param tokenAddress The address of the token received
     * @param amount The amount received if its token
     */

    function _autoSaveWhenReceive(
        address tokenAddress,
        uint256 amount
    ) private {
        uint precisionPercent = s_autoSavingPercent * 100;

        uint256 saveAmount = (amount * precisionPercent) / 10000;

        if (s_canAutoSave && saveAmount > 0) {
            if (tokenAddress == address(0)) {
                (bool success, ) = businessSaving.call{value: saveAmount}("");
                if (!success) {
                    revert BUSINESSCONTRACT__TRANSACTIONFAILED();
                }
            } else {
                bool success = IERC20(tokenAddress).transfer(
                    businessSaving,
                    saveAmount
                );
                if (!success) {
                    revert BUSINESSCONTRACT__TRANSACTIONFAILED();
                }
            }
        }
    }

    /**
     * @dev The following function sets the nft address
     * @dev Called when they deploy nft/sbt contract so as to set address
     * @param nftAddress The nftAddress of the business that has employees.
     */

    function setPayToEmployee(address nftAddress) external onlyOwner {
        s_businessNFTAddress = nftAddress;
    }

    /**
     * @dev Called on token contract deployment to set token address
     * @dev WHen payer pays up to supposedToSpendToGetTokens they get
     * @dev reward set in token contract.
     * @param businessTokenAddress The business token address
     * @param supposedToSpendToGetTokens The limit to spending for reward
     */
    function setTokenAddress(
        address businessTokenAddress,
        uint256 supposedToSpendToGetTokens
    ) external onlyOwner {
        s_businessTokenAddress = businessTokenAddress;
        s_supposedToSpendForTokens = supposedToSpendToGetTokens;
    }

    /**
     * @dev Change limit for reward
     * @param newSupposedToSpend New limit to spending for reward
     */
    function changeSupposedToSpend(
        uint256 newSupposedToSpend
    ) external onlyOwner {
        s_supposedToSpendForTokens = newSupposedToSpend;
    }

    ////////////////////////////////////////
    ////////////ERC-4337 FUNCTIONS//////////
    ////////////////////////////////////////

    /**
     * @notice Owner can authorize update
     * @param newImplementation This is the new code
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal view override onlyOwner {
        (newImplementation);
    }

    /**
     * @notice The following function will validate the owners sig
     * @param userOp User called operation
     * @param userOpHash User called operation hash
     */

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        internal
        virtual
        override
        onlyEntryPoint
        returns (uint256 validationData)
    {
        bytes32 hash = userOpHash.toEthSignedMessageHash();

        if (businessOwner != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    /**
     * @notice call operation
     * @param _to is supposed to send money to the address entered
     * @param _amount The amount to call execute with
     * @param func Is the function to be executed
     */

    function _call(
        address payable _to,
        uint256 _amount,
        bytes calldata func
    ) private {
        (bool success, ) = _to.call{value: _amount}(func);
        if (!success) {
            revert BUSINESSCONTRACT__TRANSACTIONFAILED();
        }
        emit FundsMoved(_to, _amount, func);
    }

    //////////////////////////////////////////
    ////////////////GET FUNCTIONS////////////
    ////////////////////////////////////////

    function isAuthorized(address user) external view returns (bool) {
        if (address(this) == user) return true;
        return false;
    }

    function getSavingAddress() external view returns (address) {
        return businessSaving;
    }

    function getNFTAddress() external view returns (address) {
        return s_businessNFTAddress;
    }

    function getTokenAddress() external view returns (address) {
        return s_businessTokenAddress;
    }

    function getAuto() external view returns (bool) {
        return s_canAutoSave;
    }

    function getAutoPercent() external view returns (uint256) {
        return s_autoSavingPercent;
    }

    function getSpentOnBusiness(address spender) public view returns (uint256) {
        return s_spendingOnBusinessForTokens[spender];
    }

    function getSpentOnBusinessNFT(
        address spender
    ) external view returns (uint256) {
        return s_spendingOnBusinessForDrop[spender];
    }

    function getSupposedToSpend() public view returns (uint256) {
        return s_supposedToSpendForTokens;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return s_entryPoint;
    }

    function version() external pure returns (uint256) {
        return 4;
    }
}

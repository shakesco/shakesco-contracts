// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../Shakesco/PriceConverter.sol";

error BUSINESSCONTRACT__NOTOWNER();
error BUSINESSCONTRACT__TRANSACTIONFAILED();
error BUSINESSCONTRACT__NOTNFTOWNER();
error BUSINESSCONTRACT__NOEMPLOYEE();
error BUSINESSCONTRACT__CANNOTPAYEMPLOYEE();
error BUSINESSCONTRACT__NOTOWNERORENTRYPOINT();
error BUSINESSCONTRACT__INVALIDLENGTH();

/// @title Smart Wallet(Business)
/// @author Shawn Kimtai
/// @dev This contract works similar to how account works
/// @dev Only difference is 2 functions(Employee functions).

using SafeMath for uint256;
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

    event NFTTransfer(
        address indexed to,
        uint256 indexed tokenId,
        address indexed erc721Address
    );
    event SendBusiness(
        address indexed to,
        uint256 indexed amountofEth,
        uint256 indexed amountOfBusiness
    );
    event FundsMoved(
        address indexed to,
        uint256 indexed amount,
        bytes indexed func
    );
    event AutoSaved(
        uint256 indexed amount,
        uint256 indexed percent,
        address indexed thisContract
    );
    event AutoSavedFailed(string indexed failed);
    event SendToEmployee(
        uint256 indexed amount,
        address indexed employee,
        address indexed thisContract
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

    /// @dev Checks if payment to employee is allowed by business
    modifier payEmployee() {
        if (!s_canSendToEmployee) {
            revert BUSINESSCONTRACT__CANNOTPAYEMPLOYEE();
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

    /// @dev Functions below are only callable by this contract which will be
    ///      validated later if the owner of the contract called the function or
    ///      functions if executebatch.

    /**
     * @dev The following function serves as a way for business to be paid
     * @dev We have special functionality that may not apply to sending to another user
     * @dev The following function only cares about the businessToken the user has.
     * We minus, the amount of token the user has plus the NFTDiscount that the nft carries,
     * from the amount the user is supposed to send
     * @dev The NFTDISCOUNT and businessTokenBalance can however be greater than amount causing an
     * underflow and that bad. We therefore need to take care of this without using safeMath as that
     * will also throw an ERROR. We believe the implementation below is better and will not break.
     * @dev We use priceAddress to convert every aseet/token back to correct format so that owner sends
     * correct amount
     * @param _businessTokenAddress The Token address of business token that the business owns.
     * @param _businessNFTAddress The business nft address that the business owns.
     * @param _priceAddress The price address of the native asset the owner is paying
     */

    function sendToBusiness(
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _priceAddress
    ) external payable nonReentrant {
        uint256 tokenToSend;
        uint256 _amount = msg.value;

        if (
            _businessNFTAddress != address(0) ||
            _businessTokenAddress != address(0)
        ) {
            (_amount, tokenToSend) = getBusinessDiscount(
                _businessTokenAddress,
                _businessNFTAddress,
                _priceAddress,
                address(0),
                address(0),
                _amount
            );
        }

        trackTokenBuy();

        uint sendBack = msg.value - _amount;

        if (sendBack > 0) {
            (bool success, ) = msg.sender.call{value: sendBack}("");

            if (!success) {
                revert BUSINESSCONTRACT__TRANSACTIONFAILED();
            }
        }

        //if not discount or on ethereum chain we just set this to true
        bool tokenSuccess = _businessTokenAddress != address(0)
            ? IERC20(_businessTokenAddress).transfer(
                _businessTokenAddress,
                tokenToSend
            )
            : true;

        if (!tokenSuccess) {
            revert BUSINESSCONTRACT__TRANSACTIONFAILED();
        }
    }

    /**
     * @dev The below function serves the same purpose as the one above only
     * that we are sending USDT in this.
     * @param _erc20Address ERC20 address to send tokens to business
     * @param _businessTokenAddress Business token address that user owns
     * @param _amountToSend amount the user wishes to send to business
     * @param _businessNFTAddress Business NFT address to get discount given to
     * user from specific business.
     * @param _priceAddress The price address of the native asset the owner is paying
     * @param _amountToSend The pay amount
     */

    function sendERC20ToBusiness(
        address _erc20Address,
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _priceAddress,
        address _assetPriceFeed,
        uint256 _amountToSend
    ) external nonReentrant {
        uint256 tokenToSend;

        if (
            _businessNFTAddress != address(0) ||
            _businessTokenAddress != address(0)
        ) {
            (_amountToSend, tokenToSend) = getBusinessDiscount(
                _businessTokenAddress,
                _businessNFTAddress,
                _priceAddress,
                _assetPriceFeed,
                _erc20Address,
                _amountToSend
            );
        }

        trackTokenBuy();

        bool success = IERC20(_erc20Address).transferFrom(
            msg.sender,
            address(this),
            _amountToSend
        );

        bool tokenSuccess = _businessTokenAddress != address(0)
            ? IERC20(_businessTokenAddress).transferFrom(
                msg.sender,
                _businessTokenAddress,
                tokenToSend
            )
            : true;

        if (!success || !tokenSuccess) {
            revert BUSINESSCONTRACT__TRANSACTIONFAILED();
        }
    }

    /**
     * @dev The following function allows business to reward spenders with more tokens or Airdrop
     */

    function trackTokenBuy() private {
        if (s_businessTokenAddress != address(0)) {
            (bool success, ) = s_businessTokenAddress.call(
                abi.encodeWithSignature(
                    "sendForSpendingOnBusiness(address)",
                    msg.sender
                )
            );

            if (success) {
                s_spendingOnBusinessForTokens[msg.sender] = 0;
            }
        }

        if (s_businessNFTAddress != address(0)) {
            (bool success, ) = s_businessNFTAddress.call(
                abi.encodeWithSignature(
                    "airdropNFT(address,uint256)",
                    msg.sender,
                    s_spendingOnBusinessForDrop[msg.sender]
                )
            );

            if (success) {
                s_spendingOnBusinessForDrop[msg.sender] = 0;
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
        businessSaving = mySavingsAddress;
        s_autoSavingPercent = percent;
        s_canAutoSave = percent > 0 ? true : false;
    }

    /**
     * @dev The following function sets autoSaving to true.
     * @param percent The percent the business wants to autosave with every native asset credit.
     */

    function setAutoSaving(uint256 percent) external onlyOwner {
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
        if (block.chainid != 1) {
            s_businessTokenAddress = businessTokenAddress;
            s_supposedToSpendForTokens = supposedToSpendToGetTokens;
        }
    }

    /**
     * @dev Change limit for reward
     * @param newSupposedToSpend New limit to spending for reward
     */
    function changeSupposedToSpend(
        uint256 newSupposedToSpend
    ) external onlyOwner {
        if (block.chainid != 1) {
            s_supposedToSpendForTokens = newSupposedToSpend;
        }
    }

    /**
     * @notice check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * @notice deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable onlyOwner {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * @notice withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) external onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

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

    function getSpentOnBusiness(
        address spender
    ) external view returns (uint256) {
        return s_spendingOnBusinessForTokens[spender];
    }

    function getSpentOnBusinessNFT(
        address spender
    ) external view returns (uint256) {
        return s_spendingOnBusinessForDrop[spender];
    }

    function getSupposedToSpend() external view returns (uint256) {
        return s_supposedToSpendForTokens;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return s_entryPoint;
    }

    function version() external pure returns (uint256) {
        return 3;
    }

    /**
     * @dev This function will calculate the discount payer is getting from business
     */

    function getBusinessDiscount(
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _priceAddress,
        address _assetPriceAddress,
        address erc20,
        uint256 _amount
    ) private returns (uint256 amountToSend, uint256 tokenToSend) {
        (uint businessTokenBalance, uint NFTSBTDiscount) = helperForDiscount(
            _businessTokenAddress,
            _businessNFTAddress
        );

        AggregatorV3Interface price = AggregatorV3Interface(_priceAddress);
        AggregatorV3Interface priceA = AggregatorV3Interface(
            _assetPriceAddress
        );

        (bool successP, bytes memory dataP) = _businessTokenAddress.call(
            abi.encodeWithSignature("getTokenPrice()")
        );

        uint256 tokenPrice = successP && _businessTokenAddress != address(0)
            ? abi.decode(dataP, (uint))
            : 0;

        if (businessTokenBalance > 0) {
            businessTokenBalance = (tokenPrice * businessTokenBalance) / 1e18;
        }

        uint256 totalDiscount = businessTokenBalance + NFTSBTDiscount;

        amountToSend = _assetPriceAddress == address(0)
            ? _amount.getConvertionRate(price)
            : _amount.getConvertionRate(priceA);

        if (amountToSend < totalDiscount) {
            tokenToSend = NFTSBTDiscount >= amountToSend
                ? 0
                : (amountToSend - NFTSBTDiscount);
            amountToSend = 0;
        } else if (amountToSend > totalDiscount) {
            tokenToSend = businessTokenBalance;
            amountToSend -= totalDiscount;
        } else {
            tokenToSend = businessTokenBalance;
            amountToSend = 0;
        }

        s_spendingOnBusinessForTokens[msg.sender] += amountToSend;
        s_spendingOnBusinessForDrop[msg.sender] += amountToSend;

        if (erc20 != address(0)) {
            //change back
            amountToSend = amountToSend.getReverseConvertionRate(priceA);
            uint decimals = ERC20(erc20).decimals();

            uint256 decimalAdjustment = 1e18 / (10 ** decimals);

            amountToSend = amountToSend / decimalAdjustment;
        } else {
            //change back
            amountToSend = amountToSend.getReverseConvertionRate(price);
        }

        if (tokenToSend > 0) {
            tokenToSend = (tokenToSend * 1e18) / tokenPrice;
        }
    }

    function helperForDiscount(
        address _businessTokenAddress,
        address _businessNFTAddress
    ) private returns (uint256 businessTokenBalance, uint256 NFTSBTDiscount) {
        bool isTokenNotZero = _businessTokenAddress != address(0);
        bool isNFTNotZero = _businessNFTAddress != address(0);
        //Business token address
        (bool success, bytes memory data) = _businessTokenAddress.call(
            abi.encodeWithSignature("getBuyerBalance(address)", msg.sender)
        );

        (bool successT, bytes memory dataT) = _businessNFTAddress.call(
            abi.encodeWithSignature("getDiscount(address)", msg.sender)
        );

        businessTokenBalance = success && isTokenNotZero
            ? abi.decode(data, (uint256))
            : 0;

        NFTSBTDiscount = successT && isNFTNotZero
            ? abi.decode(dataT, (uint256))
            : 0;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../Shakesco/PriceConverter.sol";
import "./BusinessSavings.sol";
import "./BusinessNFT.sol";
import "./BusinessToken.sol";

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

    /**
     * @dev Receive tokens and native asset from other users.
     * @dev The functions also checks if owner wants to autosave if
     * @dev so it send part of what is receives from native asset
     * @dev to the saving address(NOTE: NOT TOKENS BUT NATIVE ASSET).
     * @dev The function also checks on the spending of payers. If they
     * @dev spend upto business limit we make low level call to the businesses
     * @dev token contract and payer receives some business token!
     * @dev SHOULD NOT FAIL.
     */
    receive() external payable {
        uint amountToSave;

        s_spendingOnBusinessForTokens[msg.sender] += msg.value;

        uint amountReached = s_spendingOnBusinessForTokens[msg.sender];

        if (block.chainid != 1) {
            if (s_businessTokenAddress != address(0)) {
                ShakescoBusinessToken businessToken = ShakescoBusinessToken(
                    s_businessTokenAddress
                );

                (bool success, ) = address(businessToken).call(
                    abi.encodeWithSignature(
                        "sendForSpendingOnBusiness(address)",
                        msg.sender
                    )
                );

                if (
                    success &&
                    s_supposedToSpendForTokens <=
                    s_spendingOnBusinessForTokens[msg.sender]
                ) {
                    s_spendingOnBusinessForTokens[msg.sender] = 0;
                }
            }

            if (s_businessNFTAddress != address(0)) {
                ShakescoBusinessToken businessNFT = ShakescoBusinessToken(
                    s_businessNFTAddress
                );

                (bool success, ) = address(businessNFT).call(
                    abi.encodeWithSignature(
                        "airdropNFT(address,uint256)",
                        msg.sender,
                        amountReached
                    )
                );

                if (success) {
                    s_spendingOnBusinessForTokens[msg.sender] = 0;
                }
            }
        }

        if (s_canAutoSave) {
            amountToSave = msg.value.mul(s_autoSavingPercent).div(100);
            (bool success, ) = businessSaving.call{value: amountToSave}("");
            if (!success) {
                emit AutoSavedFailed("Autosaving Failed!");
            }
            emit AutoSaved(amountToSave, s_autoSavingPercent, address(this));
        }
    }

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
            revert ACCOUNT__INVALIDLENGTH();
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
     * @dev The following function serves as a way for business to send money to another business
     * @dev We have special functionality that may not apply to sending to another user
     * @dev The following function only cares about the businessToken the user has.
     * We minus, the amount of token the user has plus the NFTDiscount that the nft carries,
     * from the amount the user is supposed to send
     * @dev The NFTDISCOUNT and businessTokenBalance can however be greater than amount causing an
     * underflow and that bad. We therefore need to take care of this without using safeMath as that
     * will also throw an ERROR. We believe the implementation below is better and will not break.
     * @dev We use priceAddress to convert every aseet/token back to correct format so that owner sends
     * correct amount
     * @param _to Another business address.
     * @param _businessTokenAddress The Token address of business token that the business owns.
     * @param _businessNFTAddress The business nft address that the business owns.
     * @param _priceAddress The price address of the native asset the owner is paying
     * @param _amount The pay amount
     */

    function sendToBusiness(
        address payable _to,
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _priceAddress,
        uint256 _amount
    ) external onlyOwner {
        uint256 tokenToSend;

        //if not discount just send pay. No need to perform calculation
        //which mean more gas especially for ethereum. (Tokens are only
        //in polygon)
        if (block.chainid != 1) {
            if (
                _businessNFTAddress != address(0) ||
                _businessTokenAddress != address(0)
            ) {
                (_amount, tokenToSend) = getBusinessDiscount(
                    _businessTokenAddress,
                    _businessNFTAddress,
                    _priceAddress,
                    _amount
                );
            }
        }

        //send both token and amount to send depending on discount
        (bool success, ) = _to.call{value: _amount}("");
        //if not discount or on ethereum chain we just set this to true
        bool tokenSuccess = _businessTokenAddress != address(0)
            ? IERC20(_businessTokenAddress).transfer(_to, tokenToSend)
            : true;
        if (!success || !tokenSuccess) {
            revert BUSINESSCONTRACT__TRANSACTIONFAILED();
        }
        emit SendBusiness(_to, _amount, tokenToSend);
    }

    /**
     * @notice The following function will allow users to point to employee
     * but the money they send to business a percent will be sent to employee.
     * @dev If business is willing to allow direct pay to employee, payers can
     * @dev select the employee in this business and a percent wiil go to them
     * @dev the rest to the business.
     * @param employee The employee to send money to.
     */

    function sendToEmployees(
        address payable employee
    ) external payable payEmployee {
        //Check business has nft/sbt contract
        ///also check employee is in business
        if (s_businessNFTAddress != address(0)) {
            ShakescoBusinessNFT businessnft = ShakescoBusinessNFT(
                s_businessNFTAddress
            );
            if (!businessnft.isEmployee(employee)) {
                revert BUSINESSCONTRACT__NOEMPLOYEE();
            }
            //Calculates pay to employee

            //rest to business
            uint256 sending = (msg.value).mul(s_percentToEmployee).div(100);
            uint256 receiving = msg.value - sending;

            //Remember they are still spending on business
            s_spendingOnBusinessForTokens[msg.sender] += receiving;

            (bool success, ) = employee.call{value: sending}("");
            if (!success) {
                revert BUSINESSCONTRACT__TRANSACTIONFAILED();
            }
            emit SendToEmployee(sending, employee, address(this));
        } else {
            revert BUSINESSCONTRACT__NOEMPLOYEE();
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
     * @dev The following function will allow businesses to set if
     * they want to send a percent of their employee
     * @dev Called when they deploy nft/sbt contract so as to set address
     * @param percentToEmployee The percent employee are to receive on money send.
     * @param nftAddress The nftAddress of the business that has employees.
     */

    function setPayToEmployee(
        uint256 percentToEmployee,
        address nftAddress
    ) external onlyOwner {
        s_businessNFTAddress = nftAddress;
        s_canSendToEmployee = percentToEmployee > 0 ? true : false;
        s_percentToEmployee = percentToEmployee;
    }

    /**
     * @dev Change or set if not previously set pay to employee
     * @param percentToEmployee  The percent employee are to receive on money send.
     */

    function setPercentEmployee(uint256 percentToEmployee) external onlyOwner {
        s_canSendToEmployee = true;
        s_percentToEmployee = percentToEmployee;
    }

    /**
     * @notice The following will remove sending to employees.
     */

    function removePercentToEmployee() external onlyOwner {
        s_canSendToEmployee = false;
        s_percentToEmployee = 0;
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

    function getEmpPercent() external view returns (uint256) {
        return s_percentToEmployee;
    }

    function getSpentOnBusiness(
        address spender,
        address i_priceFeed
    ) external view returns (uint256) {
        AggregatorV3Interface price = AggregatorV3Interface(i_priceFeed);
        return s_spendingOnBusinessForTokens[spender].getConvertionRate(price);
    }

    function getSupposedToSpend() external view returns (uint256) {
        return s_supposedToSpendForTokens;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return s_entryPoint;
    }

    /**
     * @dev Look at Account.sol. This function works similar to that
     * @dev This function will calculate the required pay by owner to
     *      the payee(business) giving the correct amount after discount.
     */

    function getBusinessDiscount(
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _priceAddress,
        uint256 _amount
    ) private view returns (uint256 amountToSend, uint256 tokenToSend) {
        ShakescoBusinessToken businessToken = ShakescoBusinessToken(
            _businessTokenAddress
        );
        ShakescoBusinessNFT businessNft = ShakescoBusinessNFT(
            _businessNFTAddress
        );
        AggregatorV3Interface price = AggregatorV3Interface(_priceAddress);

        uint256 businessTokenBalance;
        uint256 NFTSBTDiscount;
        amountToSend = _amount.getConvertionRate(price);

        //get tokenid
        uint discount = _businessNFTAddress != address(0)
            ? businessNft.getDiscount(address(this))
            : 0;

        if (
            _businessNFTAddress == address(0) &&
            _businessTokenAddress != address(0)
        ) {
            NFTSBTDiscount = 0;
            businessTokenBalance = businessToken.getBuyerBalance(address(this));
        } else if (
            _businessTokenAddress == address(0) &&
            _businessNFTAddress != address(0)
        ) {
            businessTokenBalance == 0;
            NFTSBTDiscount = discount;
        } else if (
            _businessNFTAddress == address(0) &&
            _businessTokenAddress == address(0)
        ) {
            businessTokenBalance == 0;
            NFTSBTDiscount = 0;
        } else {
            businessTokenBalance = businessToken.getBuyerBalance(address(this));

            NFTSBTDiscount = discount;
        }

        //convert token to currency
        uint256 tokenPrice = _businessTokenAddress != address(0)
            ? businessToken.getTokenPrice()
            : 0;

        if (businessTokenBalance > 0) {
            businessTokenBalance = (tokenPrice * businessTokenBalance) / 1e18;
        }

        //NFT already in currency

        uint256 totalDiscount = businessTokenBalance + NFTSBTDiscount;

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

        //change back
        amountToSend = amountToSend.getReverseConvertionRate(price);

        if (tokenToSend > 0) {
            tokenToSend = (tokenToSend * 1e18) / tokenPrice;
        }
    }
}

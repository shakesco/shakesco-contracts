// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../Shakesco/PriceConverter.sol";
import "../Business/BusinessToken.sol";
import "../Business/BusinessNFT.sol";
import "./Savings.sol";

error ACCOUNT__NOTOWNER();
error ACCOUNT_TRANSACTIONFAILED();
error ACCOUNT__INVALIDLENGTH();
error ACCOUNT__NOTENTRYPOINT();
error ACCOUNT__NOTEXECUTE();
error ACCOUNT__DOESNOTACCEPTREQUEST();
error ACCOUNT__CANNOTADDSELF();
error ACCOUNT__OUTOFBOUND();
error ACCOUNT__ALREADYACCEPTED();

/// @title Smart Wallet(For user)
/// @author Shawn Kimtai
/// @notice Allows owner to send and receive money through a smart wallet.
/// @dev We use account abstraction to allow users to send and receive
/// @dev ether/matic.
/// @dev This smart wallet will own autopayment,delegate, group and saving accounts.
/// @dev Also important to note that we discourage the ownership of EOAs in
/// @dev contract accounts. We instead employ tss(threshold cryptography) where
/// @dev we can use public key P which is the same for all participants n in tss
/// @dev to derive a valid ethereum address and that will be the owner.
/// @dev Now this wallet is owned by multiple owners(just like having guardians) but
/// @dev even better you don't have to pay gas to change owner. Entrypoint makes it
/// @dev easier for us to have all operations handled by this contract and still
/// @dev have the n partipants own those other accounts

using SafeMath for uint256;
using ECDSA for bytes32;
using PriceConverter for uint256;

contract ShakescoAccount is
    IERC721Receiver,
    BaseAccount,
    ReentrancyGuard,
    UUPSUpgradeable,
    Initializable
{
    //owner of account
    address private i_accountOwner;
    //saving address
    address payable private savingsAddress;
    //Able to autosave. So this is the percentage that will go to
    //autosaving account
    uint256 private s_autoSavingPercent;
    //Entrypoint for calling function that account owner wants to execute
    IEntryPoint private immutable s_entryPoint;
    //to check if owner wants to autosave
    bool private s_canAutoSave;
    //check is they accept group invites
    bool private s_acceptGroupInvite;
    //groups
    mapping(address => Group) private s_groups;
    mapping(address => uint256) private s_splitPay;

    event FundsMoved(
        address indexed to,
        uint256 indexed amount,
        bytes indexed func
    );
    event NFTTransfer(
        address indexed to,
        uint256 indexed tokenId,
        address indexed erc721Address
    );
    event SendBusiness(
        address indexed to,
        uint256 indexed amountofEth,
        uint256 indexed amountOfToken
    );
    event AutoSaved(
        uint256 indexed amount,
        uint256 indexed percent,
        address indexed thisContract
    );
    event AutoSaveFailed(string indexed failed);
    event AccountInitilized(address indexed entryPoint, address indexed owner);

    /// @dev checks if contract owner called functions with this access modifier
    modifier onlyOwner() {
        if (msg.sender != address(this)) {
            revert ACCOUNT__NOTOWNER();
        }
        _;
    }

    /// @dev checks if functions with this access modifier were called by entrypoint
    modifier onlyEntryPoint() {
        if (msg.sender != address(s_entryPoint)) {
            revert ACCOUNT__NOTENTRYPOINT();
        }
        _;
    }

    /// @dev checks if functions with this access modifier were called by entrypoint
    modifier acceptingRequests() {
        if (!s_acceptGroupInvite) {
            revert ACCOUNT__DOESNOTACCEPTREQUEST();
        }
        _;
    }

    struct Group {
        string name;
        string image;
        address owner;
        bool status;
    }

    address[] private s_allGroups;

    /// @dev Initialize entrypoint here. For any change in the contract address
    ///      a new implementation of this contract has to be deployed(This saves
    ///       on gas)
    ///  @dev Also important to disable future reinitialization that may cause attackers
    ///       to exploit that vulnerability
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

    function _initialize(address accountOwner) internal virtual {
        i_accountOwner = accountOwner;
        emit AccountInitilized(address(s_entryPoint), i_accountOwner);
    }

    /**
     * @dev Receive tokens and native asset from other users.
     * @dev The functions also checks if owner wants to autosave if
     * @dev so it send part of what is receives from native asset
     * @dev to the saving address(NOTE: NOT TOKENS BUT NATIVE ASSET).
     */

    receive() external payable {
        uint256 amountToSave;

        if (s_canAutoSave) {
            amountToSave = msg.value.mul(s_autoSavingPercent).div(100);
            (bool success, ) = savingsAddress.call{value: amountToSave}("");
            if (!success) {
                emit AutoSaveFailed("AutoSaving Failed!");
            }
            emit AutoSaved(amountToSave, s_autoSavingPercent, address(this));
        }
    }

    /**
     * @notice Execute operation
     * @param _to is supposed to send money to the address entered
     * @param _amount The amount to call execute with
     * @param func Is the function to be executed
     */

    function execute(
        address payable _to,
        uint256 _amount,
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
     * @notice The following function serves as a way for users to send money to business
     * @dev We have special functionality that may not apply to sending to another user
     * @dev The following function only cares about the businessToken the user has.
     * We minus the amount of token the user has plus the NFTDiscount that the nft carries
     * from the amount the user is supposed to send
     * @dev The NFTDISCOUNT and businessTokenBalance can however be greater than amount causing an
     * underflow and thats bad. We therefore need to take care of this without using safeMath as that
     * will also throw an ERROR. We believe the implementation below is better and will not break.
     * @dev We use priceAddress to convert every aseet/token back to correct format so that owner sends
     * correct amount
     * @param _to Business the user wants to send funds to.
     * @param _businessTokenAddress The Token address of business token that the user owns tokens from.
     * @param _businessNFTAddress The business nft address that the user owns NFT/SBT
     * @param _priceAddress The price address of the native asset the owner is paying
     * @param _amount The pay amount
     */

    function sendToBusiness(
        address payable _to,
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _priceAddress,
        uint256 _amount
    ) external nonReentrant onlyOwner {
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
            revert ACCOUNT_TRANSACTIONFAILED();
        }
        emit SendBusiness(_to, _amount, tokenToSend);
    }

    /// @dev The function below is called when owner are to receive a collectible(NFT/SBT)
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @dev The below function allows split payment
     * @param puller The person allowed to pull from account
     * @param amount The amount to pull from account
     */
    function acceptSplitPay(address puller, uint256 amount) external onlyOwner {
        s_splitPay[puller] += amount;
    }

    /**
     * @dev The below function removes split payment
     * @param puller The person allowed to pull from account
     */
    function removeSplitPay(address puller) external onlyOwner {
        s_splitPay[puller] = 0;
    }

    /**
     * @dev The function below allows split payment to be used
     * @param receiver The payee
     * @param amount The amount
     */
    function pullSplitPay(address receiver, uint amount) external {
        uint left = s_splitPay[msg.sender];
        if (left <= 0 || amount > left) {
            revert ACCOUNT_TRANSACTIONFAILED();
        }

        s_splitPay[msg.sender] -= amount;

        (bool success, ) = receiver.call{value: amount}("");

        if (!success) {
            revert ACCOUNT_TRANSACTIONFAILED();
        }
    }

    /**
     * @dev The following function servers to add account to group
     * @param group The group you are being invited to
     * @param owner The owner of the group
     * @param name The name of the group
     */

    function inviteToGroup(
        address group,
        address owner,
        string calldata name,
        string calldata image
    ) external acceptingRequests {
        if (owner == address(this) || s_groups[group].status) {
            revert ACCOUNT__CANNOTADDSELF();
        }

        s_groups[group].name = name;
        s_groups[group].image = image;
        s_groups[group].owner = owner;
        s_groups[group].status = false;
        s_allGroups.push(group);
    }

    /**
     * @dev Account can accept invitations to groups with this function
     * @param group The group you want to accept invitation to.
     */

    function acceptGroupInvite(address group) external onlyOwner {
        if (s_groups[group].status) {
            revert ACCOUNT__ALREADYACCEPTED();
        }

        s_groups[group].status = true;
        (bool success, ) = group.call(abi.encodeWithSignature("addToGroup()"));

        if (!success) {
            revert ACCOUNT_TRANSACTIONFAILED();
        }
    }

    /**
     * @dev Exit group
     * @param group Group to exit
     */

    function exitGroup(address group) external onlyOwner {
        s_groups[group].status = false;

        uint select;
        uint len = s_allGroups.length;
        for (uint i = 0; i < len; ) {
            if (s_allGroups[i] == group) {
                select = i;
                break;
            }
            unchecked {
                ++i;
            }
        }
        remove(select);

        (bool success, ) = group.call(abi.encodeWithSignature("exitGroup()"));

        if (!success) {
            revert ACCOUNT_TRANSACTIONFAILED();
        }
    }

    function changeRequestStatus(bool status) external onlyOwner {
        s_acceptGroupInvite = status;
    }

    /**
     * @dev The following function will help users to set their savings address for
     * autosaving.
     * @dev Called on deployment of saving
     * @param mySavingsAddress The address the user has received as their address
     */

    function setSavingsAddress(
        address payable mySavingsAddress,
        uint256 percent
    ) external onlyOwner {
        savingsAddress = mySavingsAddress;
        s_autoSavingPercent = percent;
        percent > 0 ? s_canAutoSave = true : s_canAutoSave = false;
    }

    /**
     * @dev The following function sets autoSaving to true.
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

    ////////////////////////////////////////
    ////////////GET FUNCTIONS///////////////
    ////////////////////////////////////////

    function getSavingAddress() external view returns (address) {
        return savingsAddress;
    }

    function getAuto() external view returns (bool) {
        return s_canAutoSave;
    }

    function getSplitPay(address pay) external view returns (uint) {
        return s_splitPay[pay];
    }

    function getGroups() external view returns (address[] memory) {
        return s_allGroups;
    }

    function getGroupDetails(
        address group
    ) external view returns (bool, string memory, string memory, address) {
        return (
            s_groups[group].status,
            s_groups[group].name,
            s_groups[group].image,
            s_groups[group].owner
        );
    }

    function getRequest() external view returns (bool) {
        return s_acceptGroupInvite;
    }

    function getAutoPercent() external view returns (uint256) {
        return s_autoSavingPercent;
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

        if (i_accountOwner != hash.recover(userOp.signature))
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
            revert ACCOUNT_TRANSACTIONFAILED();
        }
        emit FundsMoved(_to, _amount, func);
    }

    function isAuthorized(address user) external view returns (bool) {
        if (address(this) == user) return true;
        return false;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return s_entryPoint;
    }

    /**
     * @dev This function will calculate the required pay by owner to
     *      the payee(business) giving the correct amount after discount.
     */

    function getBusinessDiscount(
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _priceAddress,
        uint256 _amount
    ) private view returns (uint256 amountToSend, uint256 tokenToSend) {
        //Business token address
        ShakescoBusinessToken businessToken = ShakescoBusinessToken(
            _businessTokenAddress
        );
        //business nft/sbt address
        ShakescoBusinessNFT businessNft = ShakescoBusinessNFT(
            _businessNFTAddress
        );
        //Changes amount to send to native currency because discounts are also in native currency
        AggregatorV3Interface price = AggregatorV3Interface(_priceAddress);

        //Get owner business token balance
        uint256 businessTokenBalance;
        //get owner nft/sbt discount if they own the business nft/sbt
        uint256 NFTSBTDiscount;
        //convertion to native currency
        amountToSend = _amount.getConvertionRate(price);
        //get tokenid
        uint discount = _businessNFTAddress != address(0)
            ? businessNft.getDiscount(address(this))
            : 0;

        if (
            _businessNFTAddress == address(0) &&
            _businessTokenAddress != address(0)
        ) {
            //if user has token but no nft/sbt
            NFTSBTDiscount = 0;
            businessTokenBalance = businessToken.getBuyerBalance(address(this));
        } else if (
            _businessTokenAddress == address(0) &&
            _businessNFTAddress != address(0)
        ) {
            //if user has nft/sbt but no token
            businessTokenBalance == 0;
            NFTSBTDiscount = discount;
        } else if (
            _businessNFTAddress == address(0) &&
            _businessTokenAddress == address(0)
        ) {
            //if user has no nft/sbt and no token
            businessTokenBalance == 0;
            NFTSBTDiscount = 0;
        } else {
            //if user has both nft/sbt and token
            businessTokenBalance = businessToken.getBuyerBalance(address(this));

            NFTSBTDiscount = discount;
        }

        //convert token to currency
        //Take number of token the user has and then
        //get how much each token is worth
        uint256 tokenPrice = _businessTokenAddress != address(0)
            ? businessToken.getTokenPrice()
            : 0;

        if (businessTokenBalance > 0) {
            businessTokenBalance = (tokenPrice * businessTokenBalance) / 1e18;
        }
        //NFT already in currency

        //Add token and nft/sbt discount to get the total discount
        uint256 totalDiscount = businessTokenBalance + NFTSBTDiscount;

        //if discount is greater than amount to send, send amount
        //is removed and we instead send token. We let nft/sbt discount
        //take more priority so that we can save tokens for those who
        //have both discounts
        if (amountToSend < totalDiscount) {
            tokenToSend = NFTSBTDiscount >= amountToSend
                ? 0
                : (amountToSend - NFTSBTDiscount);
            amountToSend = 0;
        } else if (amountToSend > totalDiscount) {
            //if amount is greater than discount
            //send all tokens then minus discount from amount to send
            tokenToSend = businessTokenBalance;
            amountToSend -= totalDiscount;
        } else {
            //if equal send all tokens but not amount to send
            tokenToSend = businessTokenBalance;
            amountToSend = 0;
        }

        //change back from native currency
        amountToSend = amountToSend.getReverseConvertionRate(price);

        //Don't forget we also need to convert token
        if (tokenToSend > 0) {
            tokenToSend = (tokenToSend * 1e18) / tokenPrice;
        }
    }

    function remove(uint _index) private {
        uint len = s_allGroups.length;
        if (_index > len) {
            revert ACCOUNT__OUTOFBOUND();
        }

        for (uint i = _index; i < len - 1; ) {
            s_allGroups[i] = s_allGroups[i + 1];
            unchecked {
                ++i;
            }
        }
        s_allGroups.pop();
    }
}

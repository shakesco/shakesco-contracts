// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error ACCOUNT__NOTOWNER();
error ACCOUNT_TRANSACTIONFAILED();
error ACCOUNT__INVALIDLENGTH();
error ACCOUNT__NOTENTRYPOINT();
error ACCOUNT__NOTEXECUTE();

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

using ECDSA for bytes32;

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
    //split payment mapping for people allowed to pull from account
    mapping(address => uint256) private s_splitPay;
    //Group array
    address[] private s_allGroups;

    event FundsMoved(
        address indexed to,
        uint256 indexed amount,
        bytes indexed func
    );
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

    struct Group {
        string name;
        string image;
        address owner;
        bool status;
    }

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

    receive() external payable {}

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
        if (left == 0 || amount > left) {
            revert ACCOUNT_TRANSACTIONFAILED();
        }

        s_splitPay[msg.sender] -= amount;

        (bool success, ) = receiver.call{value: amount}("");

        if (!success) {
            revert ACCOUNT_TRANSACTIONFAILED();
        }
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
        if (percent > 100) {
            revert ACCOUNT_TRANSACTIONFAILED();
        }

        savingsAddress = mySavingsAddress;
        s_autoSavingPercent = percent;
        percent > 0 ? s_canAutoSave = true : s_canAutoSave = false;
    }

    /**
     * @dev The following function sets autoSaving to true.
     */

    function setAutoSaving(uint256 percent) external onlyOwner {
        if (percent > 100) {
            revert ACCOUNT_TRANSACTIONFAILED();
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
     * @dev The following function will help users to receive ether or token
     * and autosave if they have set autosaving
     * @param _tokenAddress The address of the token received
     * @param _amount The amount received if its token
     */

    function receiveAndSave(
        address _tokenAddress,
        uint256 _amount
    ) external payable nonReentrant {
        if (_tokenAddress == address(0)) {
            _autoSaveWhenReceive(_tokenAddress, msg.value);
        } else {
            bool success = IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            );

            if (!success) {
                revert ACCOUNT_TRANSACTIONFAILED();
            }

            _autoSaveWhenReceive(_tokenAddress, _amount);
        }
    }

    /**
     * @dev The following function will help users to auto save when they receive
     * ether or token
     * @param _tokenAddress The address of the token received
     * @param _amount The amount received if its token
     */

    function _autoSaveWhenReceive(
        address _tokenAddress,
        uint256 _amount
    ) private {
        uint precisionPercent = s_autoSavingPercent * 100;

        uint256 saveAmount = (_amount * precisionPercent) / 10000;

        if (s_canAutoSave && saveAmount > 0) {
            if (_tokenAddress == address(0)) {
                (bool success, ) = savingsAddress.call{value: saveAmount}("");
                if (!success) {
                    revert ACCOUNT_TRANSACTIONFAILED();
                }
            } else {
                bool success = IERC20(_tokenAddress).transfer(
                    savingsAddress,
                    saveAmount
                );
                if (!success) {
                    revert ACCOUNT_TRANSACTIONFAILED();
                }
            }
        }
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

    function getAutoPercent() external view returns (uint256) {
        return s_autoSavingPercent;
    }

    function isAuthorized(address user) external view returns (bool) {
        if (address(this) == user) return true;
        return false;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return s_entryPoint;
    }

    function version() external pure returns (uint256) {
        return 4;
    }
}

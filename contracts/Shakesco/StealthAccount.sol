// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@account-abstraction/contracts/core/BaseAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

error ACCOUNT__NOTOWNER();
error ACCOUNT_TRANSACTIONFAILED();
error ACCOUNT__INVALIDLENGTH();
error ACCOUNT__NOTENTRYPOINT();
error ACCOUNT__OUTOFBOUND();

/// @title Stealth Smart Wallet
/// @author Shawn Kimtai
/// @notice This is a Stealth Smart account that will handle users assets.
/// @dev Stealth payments will be sent to this Smart wallet. This will help users pay fee with token if they receive token

using ECDSA for bytes32;

contract StealthShakescoAccount is
    IERC721Receiver,
    BaseAccount,
    UUPSUpgradeable,
    Initializable
{
    //owner of account
    address private i_accountOwner;
    //Entrypoint for calling function that account owner wants to execute
    IEntryPoint private immutable s_entryPoint;

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
    }

    receive() external payable {}

    /**
     * @notice Execute operation
     * @param _to The contract/address to call
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
     * @param _to The contract/address to call
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
     * @notice Owner can authorize update
     * @param newImplementation This is the new implementation contract
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
     * @param _to The contract/address to call
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
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return s_entryPoint;
    }

    function version() external pure returns (uint256) {
        return 1;
    }
}

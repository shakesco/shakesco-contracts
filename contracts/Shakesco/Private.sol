// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error PRIVATE__NOTOWNER();
error PRIVATE__TXFAILED();
error PRIVATE__NOTENOUGHFUNDS();

/**
 * @title Private transactions with Stealth Addresses
 * @author Shawn Kimtai
 * @notice This contract's main purpose is to emit events for stealth payments
 * @dev This contract allows anyone to send ETH or tokens to a stealth address.
 * @dev We avoid handling tokens directly in this contract to prevent 'blacklisting'
 * @dev The contract emits an event with the details of the transaction making it easy for transaction fetching.
 * @dev The receiver only need to share their view private key(which cannot spend funds) with Shakesco so as to check across announcements for the assets
        that belong to them.
 * @dev The contract also allows the owner to withdraw fees and change the fee percentage. 
 */

contract ShakescoPrivate is ReentrancyGuard {
    address internal constant ETH_TOKEN_PLACHOLDER =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address private i_owner;
    uint256 private s_fee;
    uint256 constant FEE_DENOMINATOR = 1000000;

    event Announcement(
        address indexed smartWallet,
        address indexed receiver,
        uint256 amount,
        uint256 salt,
        address indexed tokenAddress,
        bytes32 pkx,
        bytes32 ciphertext
    );

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert PRIVATE__NOTOWNER();
        }
        _;
    }

    constructor(uint256 payFee, address owner) {
        s_fee = payFee;
        i_owner = owner;
    }

    receive() external payable {}

    /**
     * @notice Send ETH to the stealth address
     * @param _smartWallet The smart stealth address
     * @param _recipient The stealth address
     * @param _salt Random salt value
     * @param _pkx public key X coordinate
     * @param _ciphertext Encrypted random number
     */
    function sendEth(
        address _smartWallet,
        address payable _recipient,
        uint256 _salt,
        bytes32 _pkx,
        bytes32 _ciphertext
    ) external payable {
        uint256 _amountSent;

        uint takeFee = (msg.value * s_fee) / FEE_DENOMINATOR;

        _amountSent = msg.value - takeFee;

        (bool success, ) = _smartWallet.call{value: _amountSent}("");
        if (!success) {
            revert PRIVATE__TXFAILED();
        }

        emit Announcement(
            _smartWallet,
            _recipient,
            _amountSent,
            _salt,
            ETH_TOKEN_PLACHOLDER,
            _pkx,
            _ciphertext
        );
    }

    /**
     * @notice Send Token Or NFT to the smart stealth address
     * @param _smartWallet The smart stealth address
     * @param _recipient The stealth address
     * @param _tokenAddress The token address
     * @param _amount The amount of token sent
     * @param _salt Random salt value
     * @param _pkx public key X coordinate
     * @param _ciphertext Encrypted random number
     */
    function sendToken(
        address _smartWallet,
        address payable _recipient,
        address _tokenAddress,
        uint256 _amount,
        uint256 _salt,
        bytes32 _pkx,
        bytes32 _ciphertext
    ) external {
        emit Announcement(
            _smartWallet,
            _recipient,
            _amount,
            _salt,
            _tokenAddress,
            _pkx,
            _ciphertext
        );
    }

    function withdrawFee(
        address payable _to,
        uint256 _amount,
        bytes calldata func
    ) external nonReentrant onlyOwner {
        (bool success, ) = _to.call{value: _amount}(func);
        if (!success) {
            revert PRIVATE__TXFAILED();
        }
    }

    function changeFee(uint256 _newFee) external onlyOwner {
        s_fee = _newFee;
    }

    function changeOwner(address newOwner) external onlyOwner {
        i_owner = newOwner;
    }

    function getFee() external view returns (uint256) {
        return s_fee;
    }
}

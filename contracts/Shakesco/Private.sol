// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../Business/BusinessNFT.sol";
import "../Business/BusinessToken.sol";
import "../Shakesco/PriceConverter.sol";

error PRIVATE__NOTOWNER();
error PRIVATE__TXFAILED();
error PRIVATE__NOTENOUGHFUNDS();
error PRIVATE__INVALIDLENGTH();
error PRIVATE__NOTENOUGHFEE();

/**
 * @title Private tx with stealth payments
 * @author Shawn kimtai
 * @notice Contract that allows for payments where only the sender and receiver
 * know the destination of money.
 */

using SafeMath for uint256;
using PriceConverter for uint256;

contract ShakescoPrivate is ReentrancyGuard {
    address internal constant ETH_TOKEN_PLACHOLDER =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address private i_owner;
    uint256 private s_fee;
    uint256 private _totalFee;
    mapping(address => uint256) private s_payersProceeds;

    event Announcement(
        address indexed receiver,
        uint256 amount,
        address indexed tokenAddress,
        address businessTokenAddress,
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
        _totalFee = 0;
        i_owner = owner;
    }

    receive() external payable {}

    /**
     * @notice Send ETH to the stealth address
     * @param _recipient The stealth address
     * @param _pkx public key X coordinate
     * @param _ciphertext Encrypted random number
     */
    function sendEth(
        address payable _recipient,
        bytes32 _pkx,
        bytes32 _ciphertext
    ) external payable {
        uint256 _amountSent;

        uint takeFee = (msg.value * s_fee) / 100;

        _amountSent = msg.value - takeFee;

        _totalFee += takeFee;

        (bool success, ) = _recipient.call{value: _amountSent}("");
        if (!success) {
            revert PRIVATE__TXFAILED();
        }
        emit Announcement(
            _recipient,
            _amountSent,
            ETH_TOKEN_PLACHOLDER,
            ETH_TOKEN_PLACHOLDER,
            _pkx,
            _ciphertext
        );
    }

    /**
     * @notice This allows users to send ETH to business stealth address
     * @param _recipient The stealth address
     * @param _businessTokenAddress The business Token address
     * @param _businessNFTAddress Business NFT address
     * @param _pkx public key X coordinate
     * @param _ciphertext Encrypted random number
     */

    function sendToBusiness(
        address payable _recipient,
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _priceAddress,
        bytes32 _pkx,
        bytes32 _ciphertext
    ) external payable nonReentrant {
        uint256 amountToSend;

        uint takeFee = (msg.value * s_fee) / 100;

        amountToSend = msg.value - takeFee;
        _totalFee += takeFee;

        uint256 tokenToSend;

        if (block.chainid != 1) {
            if (
                _businessNFTAddress != address(0) ||
                _businessTokenAddress != address(0)
            ) {
                (amountToSend, tokenToSend) = getBusinessDiscount(
                    _businessTokenAddress,
                    _businessNFTAddress,
                    _priceAddress,
                    amountToSend
                );
            }
        }

        uint256 proceeds = msg.value - (amountToSend + takeFee);
        s_payersProceeds[msg.sender] += proceeds;

        (bool success, ) = _recipient.call{value: amountToSend}("");
        bool tokenSuccess = _businessTokenAddress != address(0)
            ? IERC20(_businessTokenAddress).transferFrom(
                msg.sender,
                _recipient,
                tokenToSend
            )
            : true;
        if (!success || !tokenSuccess) {
            revert PRIVATE__TXFAILED();
        }
        emit Announcement(
            _recipient,
            amountToSend,
            ETH_TOKEN_PLACHOLDER,
            _businessTokenAddress,
            _pkx,
            _ciphertext
        );
    }

    function withdrawEthFee(
        address payable _to,
        uint256 _amount
    ) external nonReentrant onlyOwner {
        if (_totalFee < _amount) {
            revert PRIVATE__NOTENOUGHFUNDS();
        }

        (bool success, ) = _to.call{value: _amount}("");
        if (!success) {
            revert PRIVATE__TXFAILED();
        }
    }

    function payerProceeds(uint256 amount) external nonReentrant {
        if (s_payersProceeds[msg.sender] < amount) {
            revert PRIVATE__NOTENOUGHFUNDS();
        }
        s_payersProceeds[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
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

    function getProceeds(address payer) external view returns (uint256) {
        return s_payersProceeds[payer];
    }

    function getShakescoProceeds() external view onlyOwner returns (uint256) {
        return _totalFee;
    }

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
        //Convert To currency
        amountToSend = _amount.getConvertionRate(price);

        uint discount = _businessNFTAddress != address(0)
            ? businessNft.getDiscount(msg.sender)
            : 0;

        if (
            _businessNFTAddress == address(0) &&
            _businessTokenAddress != address(0)
        ) {
            NFTSBTDiscount = 0;
            businessTokenBalance = businessToken.getBuyerBalance(
                address(msg.sender)
            );
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
            businessTokenBalance = businessToken.getBuyerBalance(
                address(msg.sender)
            );

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

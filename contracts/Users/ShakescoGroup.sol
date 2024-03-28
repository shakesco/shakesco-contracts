// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../Business/BusinessNFT.sol";
import "../Business/BusinessToken.sol";
import "../Shakesco/PriceConverter.sol";

error SHAKESCOGROUP__TXFAILED();
error SHAKESCOGROUP__CANNOTREMOVESELF();
error SHAKESCOGROUP__NOTREQUESTED();
error SHAKESCOGROUP__CANNOTCONTRIBUTEANYMORE();
error SHAKESCOGROUP__OUTOFBOUND();
error SHAKESCOGROUP__NOTENOUGHFUNDS();
error SHAKESCOGROUP__CANNOTRESET();
error SHAKESCOGROUP__NOTFOUND();
error SHAKESCOGROUP__TARGETNOTMET();
error SHAKESCOGROUP__NOTALLOWEDTOTARGETSAVINGS();
error SHAKESCOGROUP__NOTALLOWEDTOTARGET();

using PriceConverter for uint256;

contract ShakescoGroup is ReentrancyGuard, UUPSUpgradeable, Initializable {
    mapping(address => Groups) private s_groups;
    //owner of group
    address payable owner;
    //Amount they will need to reach so as to withdraw
    uint256 private s_amountToReach;
    //Time period for saving
    uint256 private s_timePeriod;
    //Last timestamp saved
    uint256 private s_lastTimeStamp;
    //Able to reset after withdrawal
    bool private s_canreset;
    //Should we have target contribution
    bool private s_targetContribution;
    //period
    uint private s_targetContributionPeriod;
    //amount
    uint private s_targetContributionAmount;
    //request user
    mapping(address => bool) private s_requestedUsers;
    //string group name
    string private s_groupName;
    //string group image
    string private s_groupImage;
    AggregatorV3Interface private immutable nativepricefeed;

    event GroupInitilized(address indexed owner);

    /// @dev checks if contract owner called functions with this access modifier
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert ACCOUNT__NOTOWNER();
        }
        _;
    }

    modifier onlyRequested(address caller) {
        if (!s_requestedUsers[caller]) {
            revert SHAKESCOGROUP__NOTREQUESTED();
        }
        _;
    }

    /// @dev only reset after withdrawal
    modifier _canReset() {
        if (!s_canreset) {
            revert SHAKESCOGROUP__CANNOTRESET();
        }
        _;
    }

    struct Groups {
        address[] group;
        uint[] groupBalance;
        uint[] groupSavingContribution;
        uint ownerBalance;
        uint ownerSavingContribution;
    }

    constructor(address priceFeed) {
        nativepricefeed = AggregatorV3Interface(priceFeed);
        _disableInitializers();
    }

    /**
     * @notice Initializes implementation for contract
     * @param accountOwner Sets owner of contract
     */
    function initialize(
        address accountOwner,
        uint256 amountToReach,
        uint256 timePeriod,
        bool target,
        string calldata name,
        string calldata image
    ) public virtual initializer {
        _initialize(
            accountOwner,
            amountToReach,
            timePeriod,
            target,
            name,
            image
        );
    }

    function _initialize(
        address accountOwner,
        uint256 amountToReach,
        uint256 timePeriod,
        bool targetContribution,
        string calldata name,
        string calldata image
    ) internal virtual {
        owner = payable(accountOwner);
        s_amountToReach = amountToReach;
        s_requestedUsers[accountOwner] = true;
        s_canreset = s_amountToReach > 0 ? false : true;
        s_lastTimeStamp = block.timestamp;
        s_groupName = name;
        s_groupImage = image;
        s_timePeriod = timePeriod;
        s_targetContribution = targetContribution;
        emit GroupInitilized(owner);
    }

    /**
     * @dev Owner of group can request users to join
     * @dev That is only if the user allows request
     * @param groupMember The member you want to add to group
     */

    function requestUsers(address groupMember) external onlyOwner {
        s_requestedUsers[groupMember] = true;
        (bool success, ) = groupMember.call(
            abi.encodeWithSignature(
                "inviteToGroup(address,address,string,string)",
                address(this),
                owner,
                s_groupName,
                s_groupImage
            )
        );

        if (!success) {
            revert SHAKESCOGROUP__TXFAILED();
        }
    }

    /**
     * @dev Requested users can accept to join group with the below function
     */
    function addToGroup() external onlyRequested(msg.sender) {
        s_groups[owner].group.push(msg.sender);
        if (
            s_groups[owner].groupBalance.length > 0 ||
            s_groups[owner].groupSavingContribution.length > 0
        ) {
            //copy the list of amount
            uint[] memory copy = s_groups[owner].groupBalance;
            uint[] memory copy2 = s_groups[owner].groupSavingContribution;
            //create a new one
            uint[] memory newcopy = new uint[](s_groups[owner].group.length);
            uint[] memory newcopy2 = new uint[](s_groups[owner].group.length);
            //loop through and add the previos numbe5rs
            for (uint i; i < newcopy.length; ) {
                if (i == newcopy.length - 1) {
                    newcopy[i] = 0;
                    newcopy2[i] = 0;
                } else {
                    newcopy[i] = copy[i];
                    newcopy2[i] = copy2[i];
                }
                unchecked {
                    ++i;
                }
            }
            s_groups[owner].groupBalance = newcopy;
            s_groups[owner].groupSavingContribution = copy2;
        } else {
            s_groups[owner].groupBalance = new uint[](
                s_groups[owner].group.length
            );
            s_groups[owner].groupSavingContribution = new uint[](
                s_groups[owner].group.length
            );
        }
    }

    /**
     * @notice Send from group to anyone can also be private
     * @param _recipient The address
     * @param amount Amount to send
     */
    function send(
        address payable _recipient,
        uint amount,
        bytes calldata func
    ) external onlyRequested(msg.sender) {
        uint select;
        bool found;
        uint len = s_groups[owner].group.length;
        for (uint i = 0; i < len; ) {
            if (s_groups[owner].group[i] == msg.sender) {
                select = i;
                found = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!found && msg.sender != owner) {
            revert SHAKESCOGROUP__NOTFOUND();
        }

        if (
            (s_groups[owner].groupBalance.length > 0 &&
                s_groups[owner].groupBalance[select] < amount &&
                msg.sender != owner) ||
            (s_groups[owner].ownerBalance < amount && msg.sender == owner)
        ) {
            revert SHAKESCOGROUP__NOTENOUGHFUNDS();
        }

        msg.sender == owner
            ? s_groups[owner].ownerBalance -= amount
            : s_groups[owner].groupBalance[select] -= amount;

        (bool success, ) = _recipient.call{value: amount}(func);
        if (!success) {
            revert SHAKESCOGROUP__TXFAILED();
        }
    }

    /**
     * @notice This allows users to send ETH to business stealth address or normal pay
     * @param _recipient The stealth address or normal address
     * @param _businessTokenAddress The business Token address
     * @param _businessNFTAddress Business NFT address
     */

    function sendToBusiness(
        address payable _recipient,
        uint amount,
        address _businessTokenAddress,
        address _businessNFTAddress,
        address _priceAddress,
        bytes calldata func
    ) external nonReentrant onlyRequested(msg.sender) {
        uint amountToSend;
        uint tokenToSend;
        bool found;
        uint select;
        bool check = keccak256(func) == keccak256(bytes(""));
        uint len = s_groups[owner].group.length;
        for (uint i = 0; i < len; ) {
            if (s_groups[owner].group[i] == msg.sender) {
                select = i;
                found = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!found && msg.sender != owner) {
            revert SHAKESCOGROUP__NOTFOUND();
        }

        if (
            (s_groups[owner].groupBalance.length > 0 &&
                s_groups[owner].groupBalance[select] < amount &&
                msg.sender != owner) ||
            (s_groups[owner].ownerBalance < amount && msg.sender == owner)
        ) {
            revert SHAKESCOGROUP__NOTENOUGHFUNDS();
        }

        msg.sender == owner
            ? s_groups[owner].ownerBalance -= amount
            : s_groups[owner].groupBalance[select] -= amount;
        uint copyamount = amount;
        if (block.chainid != 1 && check) {
            if (
                _businessNFTAddress != address(0) ||
                _businessTokenAddress != address(0)
            ) {
                (amountToSend, tokenToSend) = getBusinessDiscount(
                    _businessTokenAddress,
                    _businessNFTAddress,
                    _priceAddress,
                    copyamount
                );
            }
        }
        address copy = _recipient;
        address copytoken = _businessTokenAddress;
        (bool success, ) = copy.call{value: check ? amountToSend : copyamount}(
            func
        );

        bool tokenSuccess = copytoken != address(0) && check
            ? IERC20(copytoken).transferFrom(msg.sender, copy, tokenToSend)
            : true;

        if (!success || !tokenSuccess) {
            revert SHAKESCOGROUP__TXFAILED();
        }
    }

    function addFunds() external payable onlyRequested(msg.sender) {
        uint select;
        bool found;
        uint len = s_groups[owner].group.length;
        uint totalAmount;
        for (uint i = 0; i < len; ) {
            totalAmount += s_groups[owner].groupBalance[i];
            if (s_groups[owner].group[i] == msg.sender) {
                select = i;
                found = true;
            }
            unchecked {
                ++i;
            }
        }

        if (!found && msg.sender != owner) {
            revert SHAKESCOGROUP__NOTFOUND();
        }

        totalAmount += s_groups[owner].ownerBalance;

        uint check = totalAmount.getConvertionRate(nativepricefeed);

        if (
            (s_groups[owner].groupBalance.length > 0 &&
                s_targetContribution &&
                block.timestamp > s_targetContributionPeriod &&
                check > s_targetContributionAmount) ||
            (s_targetContribution &&
                block.timestamp > s_targetContributionPeriod &&
                check > s_targetContributionAmount)
        ) {
            revert SHAKESCOGROUP__CANNOTCONTRIBUTEANYMORE();
        }

        if (msg.sender == owner) {
            s_groups[owner].ownerBalance += msg.value;
        } else {
            s_groups[owner].groupBalance[select] += msg.value;
        }
    }

    function addToSaving() external payable onlyRequested(msg.sender) {
        uint select;
        bool found;
        uint len = s_groups[owner].group.length;
        for (uint i = 0; i < len; ) {
            if (s_groups[owner].group[i] == msg.sender) {
                select = i;
                found = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!found && msg.sender != owner) {
            revert SHAKESCOGROUP__NOTFOUND();
        }

        if (msg.sender == owner) {
            s_groups[owner].ownerSavingContribution += msg.value;
        } else {
            s_groups[owner].groupSavingContribution[select] += msg.value;
        }
    }

    function withdrawSavings(uint _amount) external onlyRequested(msg.sender) {
        uint len = s_groups[owner].group.length;
        uint totalAmount;
        for (uint i = 0; i < len; ) {
            totalAmount += s_groups[owner].groupSavingContribution[i];

            if (
                s_groups[owner].group[i] == msg.sender &&
                msg.sender != owner &&
                _amount > s_groups[owner].groupSavingContribution[i]
            ) {
                revert SHAKESCOGROUP__NOTENOUGHFUNDS();
            }

            unchecked {
                ++i;
            }
        }

        if (
            s_groups[owner].ownerSavingContribution < _amount &&
            msg.sender == owner
        ) {
            revert SHAKESCOGROUP__NOTENOUGHFUNDS();
        }

        totalAmount += s_groups[owner].ownerSavingContribution;

        uint nativeBalance = totalAmount.getConvertionRate(nativepricefeed);

        bool checkTime = true;

        if (!s_canreset) {
            if (nativeBalance < s_amountToReach) {
                revert SAVING__TARGETNOTMET();
            }

            checkTime = false;
        }

        if (s_canreset) checkTime = false;

        //Check if they have reached the amount set and time period has elapsed
        if ((block.timestamp - s_lastTimeStamp) < s_timePeriod && checkTime) {
            revert SAVING__TARGETNOTMET();
        }

        //They can now reset and set new conditions for saving
        s_canreset = true;

        (bool success, ) = msg.sender.call{value: _amount}("");

        if (!success) {
            revert SHAKESCOGROUP__TXFAILED();
        }
    }

    function resetSaving(
        uint256 newPeriod,
        uint256 newAmount
    ) external onlyOwner _canReset {
        s_timePeriod = newPeriod;
        s_lastTimeStamp = block.timestamp;
        s_amountToReach = newAmount;
        s_canreset = false;
    }

    function splitPay(
        address payee,
        uint amount
    ) external onlyRequested(msg.sender) nonReentrant {
        uint len = s_groups[owner].group.length;
        uint splitAmount = amount / (len + 1);

        if (s_groups[owner].ownerBalance < splitAmount) {
            revert SHAKESCOGROUP__NOTENOUGHFUNDS();
        }

        s_groups[owner].ownerBalance -= splitAmount;

        for (uint i = 0; i < len; ) {
            if (s_groups[owner].groupBalance[i] >= splitAmount) {
                s_groups[owner].groupBalance[i] -= splitAmount;
            } else {
                revert SHAKESCOGROUP__NOTENOUGHFUNDS();
            }

            unchecked {
                ++i;
            }
        }

        (bool success, ) = payee.call{value: amount}("");

        if (!success) {
            revert SHAKESCOGROUP__TXFAILED();
        }
    }

    function exitGroup() external onlyRequested(msg.sender) nonReentrant {
        if (msg.sender == owner) {
            revert SHAKESCOGROUP__CANNOTREMOVESELF();
        }

        uint select;
        bool found;
        uint len = s_groups[owner].group.length;
        for (uint i = 0; i < len; ) {
            if (s_groups[owner].group[i] == msg.sender) {
                select = i;
                found = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!found && msg.sender != owner) {
            revert SHAKESCOGROUP__NOTFOUND();
        }

        uint balance = s_groups[owner].groupBalance[select] +
            s_groups[owner].groupSavingContribution[select];

        s_requestedUsers[msg.sender] = false;
        remove(select);
        removeAmount(select);
        removeSaving(select);

        (bool success, ) = msg.sender.call{value: balance}("");

        if (!success) {
            revert SHAKESCOGROUP__TXFAILED();
        }
    }

    function setTargetContribution(uint amount, uint time) external onlyOwner {
        uint bal = address(this).balance.getConvertionRate(nativepricefeed);
        if (
            block.timestamp < s_targetContributionPeriod ||
            bal < s_targetContributionAmount
        ) {
            revert SHAKESCOGROUP__NOTALLOWEDTOTARGET();
        }

        s_targetContributionPeriod = time;
        s_targetContribution = true;
        s_targetContributionAmount = amount;
    }

    function getSavingInfo() external view returns (bool, uint256, uint256) {
        return (s_canreset, s_timePeriod, s_amountToReach);
    }

    function getIfRequested(address user) external view returns (bool) {
        return s_requestedUsers[user];
    }

    function getRequested() external view returns (address[] memory) {
        return s_groups[owner].group;
    }

    function getGroup() external view returns (Groups memory) {
        return s_groups[owner];
    }

    function getTargetStatus() external view returns (bool, uint256, uint256) {
        return (
            s_targetContribution,
            s_targetContributionPeriod,
            s_targetContributionAmount
        );
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

    function remove(uint _index) private {
        uint len = s_groups[owner].group.length;
        if (_index > len) {
            revert SHAKESCOGROUP__OUTOFBOUND();
        }

        for (uint i = _index; i < len - 1; ) {
            s_groups[owner].group[i] = s_groups[owner].group[i + 1];
            unchecked {
                ++i;
            }
        }
        s_groups[owner].group.pop();
    }

    function removeAmount(uint _index) private {
        uint len = s_groups[owner].groupBalance.length;
        if (_index > len) {
            revert SHAKESCOGROUP__OUTOFBOUND();
        }

        for (uint i = _index; i < len - 1; ) {
            s_groups[owner].groupBalance[i] = s_groups[owner].groupBalance[
                i + 1
            ];
            unchecked {
                ++i;
            }
        }
        s_groups[owner].groupBalance.pop();
    }

    function removeSaving(uint _index) private {
        uint len = s_groups[owner].groupSavingContribution.length;
        if (_index > len) {
            revert SHAKESCOGROUP__OUTOFBOUND();
        }

        for (uint i = _index; i < len - 1; ) {
            s_groups[owner].groupSavingContribution[i] = s_groups[owner]
                .groupSavingContribution[i + 1];
            unchecked {
                ++i;
            }
        }
        s_groups[owner].groupSavingContribution.pop();
    }
}

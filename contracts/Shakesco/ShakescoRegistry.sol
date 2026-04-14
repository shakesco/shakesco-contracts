// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

error SHAKESCOREGISTRY__NOTCALLER();
error SHAKESCOREGISTRY__FEEDNOTSET();

contract ShakescoRegistry {
    address private immutable i_caller;

    // asset => feed address
    // address(0) = native token (ETH/MATIC)
    mapping(address => address) private s_feeds;
    //set fees for contracts
    mapping(address => uint256) private s_fees;
    //set default fees by contract type
    mapping(bytes32 => uint256) private s_feesByType;
    // caller from the backend
    address private s_callerAddress;
    //collector of tolls
    address private s_tollCollector;
    //off-chain token management
    address private s_manageTokenContract;

    constructor(address caller) {
        i_caller = caller;
    }

    modifier onlyCaller() {
        if (msg.sender != i_caller) revert SHAKESCOREGISTRY__NOTCALLER();
        _;
    }

    //////////////////////////////////////////
    ////////////////SET FUNCTIONS////////////
    ////////////////////////////////////////

    function setFeed(address asset, address feed) external onlyCaller {
        s_feeds[asset] = feed;
    }

    function setFee(address contractAddress, uint256 fee) external onlyCaller {
        s_fees[contractAddress] = fee;
    }

    function setFeeByName(bytes32 name, uint256 fee) external onlyCaller {
        s_feesByType[name] = fee;
    }

    function setCaller(address newCaller) external onlyCaller {
        s_callerAddress = newCaller;
    }

    function setTollCollector(address newTollCollector) external onlyCaller {
        s_tollCollector = newTollCollector;
    }

    function setManageTokenContract(
        address manageContract
    ) external onlyCaller {
        s_manageTokenContract = manageContract;
    }

    //////////////////////////////////////////
    ////////////////GET FUNCTIONS////////////
    ////////////////////////////////////////

    function getFeed(address contractAddress) external view returns (address) {
        return s_feeds[contractAddress];
    }

    function getCaller() external view returns (address) {
        return s_callerAddress;
    }

    function getTollCollector() external view returns (address) {
        return s_tollCollector;
    }

    function getManageTokenContract() external view returns (address) {
        return s_manageTokenContract;
    }

    function getFee(
        address contractAddress,
        bytes32 feeType
    ) external view returns (uint256) {
        uint256 specificFee = s_fees[contractAddress];
        if (specificFee != 0) return specificFee;

        return s_feesByType[feeType];
    }
}

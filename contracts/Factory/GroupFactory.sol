// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {ShakescoGroup} from "../Users/ShakescoGroup.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ShakescoGroupFactory {
    ShakescoGroup public immutable accountImplementation;

    constructor(address _priceFeed) {
        accountImplementation = new ShakescoGroup(_priceFeed);
    }

    /**
     * @notice Returns the address of the newly deployed contract or
     * one already deployed
     * @param walletOwner Owner of account
     * @param salt Random no. used to create address
     */
    function deployWallet(
        address walletOwner,
        uint256 salt,
        uint256 amountToSave,
        uint256 savingPeriod,
        bool isTargetContribution,
        string calldata name,
        string calldata image
    ) external returns (ShakescoGroup) {
        address walletAddress = computeAddress(
            walletOwner,
            salt,
            amountToSave,
            savingPeriod,
            isTargetContribution,
            name,
            image
        );

        uint256 codeSize = walletAddress.code.length;
        if (codeSize > 0) {
            return ShakescoGroup(payable(walletAddress));
        } else {
            return
                ShakescoGroup(
                    payable(
                        new ERC1967Proxy{salt: bytes32(salt)}(
                            address(accountImplementation),
                            abi.encodeCall(
                                ShakescoGroup.initialize,
                                (
                                    walletOwner,
                                    amountToSave,
                                    savingPeriod,
                                    isTargetContribution,
                                    name,
                                    image
                                )
                            )
                        )
                    )
                );
        }
    }

    /**
     * @notice Deterministically compute the address of a smart wallet using Create2
     * @param walletOwner Owner of account
     * @param salt Random no. used to create address
     */
    function computeAddress(
        address walletOwner,
        uint256 salt,
        uint256 amountToSave,
        uint256 savingPeriod,
        bool isTargetContribution,
        string calldata name,
        string calldata image
    ) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(accountImplementation),
                            abi.encodeCall(
                                ShakescoGroup.initialize,
                                (
                                    walletOwner,
                                    amountToSave,
                                    savingPeriod,
                                    isTargetContribution,
                                    name,
                                    image
                                )
                            )
                        )
                    )
                )
            );
    }
}

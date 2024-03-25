// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {ShakescoBusinessSavings} from "../Business/BusinessSavings.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

contract ShakescoBusinessSavingsFactory {
    ShakescoBusinessSavings public immutable savingImplementation;

    constructor() {
        savingImplementation = new ShakescoBusinessSavings();
    }

    /**
     * @notice Returns the address of the newly deployed contract or
     * one already deployed
     * @param businessAddress Account address as the owner
     * @param salt Random no. used to create address
     * @param amountToReach Limit of saving
     * @param timeToReach Limit time of saving
     */
    function deployBusinessSaving(
        address payable businessAddress,
        uint256 salt,
        uint256 amountToReach,
        uint256 timeToReach
    ) external returns (ShakescoBusinessSavings) {
        address walletAddress = computeAddress(
            businessAddress,
            salt,
            amountToReach,
            timeToReach
        );

        uint256 codeSize = walletAddress.code.length;
        if (codeSize > 0) {
            return ShakescoBusinessSavings(payable(walletAddress));
        } else {
            return
                ShakescoBusinessSavings(
                    payable(
                        new ERC1967Proxy{salt: bytes32(salt)}(
                            address(savingImplementation),
                            abi.encodeCall(
                                ShakescoBusinessSavings.initialize,
                                (businessAddress, amountToReach, timeToReach)
                            )
                        )
                    )
                );
        }
    }

    /**
     * @notice Deterministically compute the address of a smart wallet using Create2
     * @param businessAddress Account address as the owner
     * @param salt Random no. used to create address
     * @param amountToReach Limit of saving
     * @param timeToReach Limit time of saving
     */
    function computeAddress(
        address payable businessAddress,
        uint256 salt,
        uint256 amountToReach,
        uint256 timeToReach
    ) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(savingImplementation),
                            abi.encodeCall(
                                ShakescoBusinessSavings.initialize,
                                (businessAddress, amountToReach, timeToReach)
                            )
                        )
                    )
                )
            );
    }
}

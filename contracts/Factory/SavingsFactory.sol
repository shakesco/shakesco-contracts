// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ShakescoSavings} from "../Users/Savings.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

contract ShakescoSavingsFactory {
    ShakescoSavings public immutable savingImplementation;

    constructor() {
        savingImplementation = new ShakescoSavings();
    }

    /**
     * @notice Returns the address of the newly deployed contract or
     * one already deployed
     * @param accountAddress The account contract. Can also be owner
     * @param salt Random no. used to create address
     * @param amountToReach Limit of saving
     * @param timeToReach Limit time of saving
     */
    function deploySaving(
        address payable accountAddress,
        uint256 salt,
        uint256 amountToReach,
        uint256 timeToReach
    ) external returns (ShakescoSavings) {
        address walletAddress = computeAddress(
            accountAddress,
            salt,
            amountToReach,
            timeToReach
        );

        uint256 codeSize = walletAddress.code.length;
        if (codeSize > 0) {
            return ShakescoSavings(payable(walletAddress));
        } else {
            return
                ShakescoSavings(
                    payable(
                        new ERC1967Proxy{salt: bytes32(salt)}(
                            address(savingImplementation),
                            abi.encodeCall(
                                ShakescoSavings.initialize,
                                (accountAddress, amountToReach, timeToReach)
                            )
                        )
                    )
                );
        }
    }

    /**
     * @notice Deterministically compute the address of a smart wallet using Create2
     * @param accountAddress The account contract. Can also be owner
     * @param salt Random no. used to create address
     * @param amountToReach Limit of saving
     * @param timeToReach Limit time of saving
     */
    function computeAddress(
        address payable accountAddress,
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
                                ShakescoSavings.initialize,
                                (accountAddress, amountToReach, timeToReach)
                            )
                        )
                    )
                )
            );
    }
}

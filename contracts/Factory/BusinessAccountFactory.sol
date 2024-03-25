// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Create2.sol";
import {ShakescoBusinessContract} from "../Business/BusinessContract.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ShakescoBusinessFactory {
    ShakescoBusinessContract public immutable businessImplementation;

    constructor(address _entryPoint) {
        businessImplementation = new ShakescoBusinessContract(_entryPoint);
    }

    /**
     * @notice Returns the address of the newly deployed contract or
     * one already deployed
     * @param walletOwner Owner of busines
     * @param salt Random no. used to create address
     */
    function deployWallet(
        address walletOwner,
        uint256 salt
    ) external returns (ShakescoBusinessContract) {
        address walletAddress = computeAddress(walletOwner, salt);

        uint256 codeSize = walletAddress.code.length;
        if (codeSize > 0) {
            return ShakescoBusinessContract(payable(walletAddress));
        } else {
            return
                ShakescoBusinessContract(
                    payable(
                        new ERC1967Proxy{salt: bytes32(salt)}(
                            address(businessImplementation),
                            abi.encodeCall(
                                ShakescoBusinessContract.initialize,
                                (walletOwner)
                            )
                        )
                    )
                );
        }
    }

    /**
     * @notice Deterministically compute the address of a smart wallet using Create2
     * @param walletOwner Owner of business
     * @param salt Random no. used to create address
     */
    function computeAddress(
        address walletOwner,
        uint256 salt
    ) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(businessImplementation),
                            abi.encodeCall(
                                ShakescoBusinessContract.initialize,
                                (walletOwner)
                            )
                        )
                    )
                )
            );
    }
}

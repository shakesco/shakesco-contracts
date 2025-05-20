// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {StealthShakescoAccount} from "../Shakesco/StealthAccount.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ShakescoStealthFactory {
    StealthShakescoAccount public immutable accountImplementation;

    constructor(address _entryPoint) {
        accountImplementation = new StealthShakescoAccount(_entryPoint);
    }

    /**
     * @notice Returns the address of the newly deployed contract or
     * one already deployed
     * @param walletOwner Owner of account
     * @param salt Random no. used to create address
     */
    function deployWallet(
        address walletOwner,
        uint256 salt
    ) external returns (StealthShakescoAccount) {
        address walletAddress = computeAddress(walletOwner, salt);

        uint256 codeSize = walletAddress.code.length;
        if (codeSize > 0) {
            return StealthShakescoAccount(payable(walletAddress));
        } else {
            return
                StealthShakescoAccount(
                    payable(
                        new ERC1967Proxy{salt: bytes32(salt)}(
                            address(accountImplementation),
                            abi.encodeCall(
                                StealthShakescoAccount.initialize,
                                (walletOwner)
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
        uint256 salt
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
                                StealthShakescoAccount.initialize,
                                (walletOwner)
                            )
                        )
                    )
                )
            );
    }
}

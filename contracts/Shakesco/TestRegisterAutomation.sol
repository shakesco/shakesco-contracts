// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address upkeepContract;
    uint32 gasLimit;
    address adminAddress;
    uint8 triggerType;
    bytes checkData;
    bytes triggerConfig;
    bytes offchainConfig;
    uint96 amount;
}

interface AutomationRegistrarInterface {
    function registerUpkeep(
        RegistrationParams calldata requestParams
    ) external returns (uint256);

    function cancel(bytes32 hash) external;
}

contract Automate {
    LinkTokenInterface public immutable i_link;
    AutomationRegistrarInterface public immutable i_registrar;
    uint256[] private id;

    receive() external payable {}

    constructor(
        LinkTokenInterface link,
        AutomationRegistrarInterface registrar
    ) {
        i_link = link;
        i_registrar = registrar;
    }

    function createUpkeep(RegistrationParams calldata requestParams) external {
        i_link.approve(address(i_registrar), requestParams.amount);
        uint256 upkeepId = i_registrar.registerUpkeep(requestParams);
        if (upkeepId != 0) {
            id.push(upkeepId);
        } else {
            revert("auto-approve disabled");
        }
    }

    // function fundIds() external {
    //     uint len = id.length;
    //     uint256 balance = i_link.balanceOf(address(this));
    //     i_link.approve(address(i_registrar), balance);
    //     for (uint256 i = 0; i < len; ) {
    //         i_link.transferAndCall(id[i], 5000000000000000000,"0x");
    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    function takeOut(bytes32 userId) external {
        i_registrar.cancel(userId);
    }

    function withdraw(uint amount) external {
        i_link.transfer(msg.sender, amount);
    }

    function getIds() external view returns (uint256[] memory) {
        return id;
    }
}

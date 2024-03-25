// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    receive() external payable {}

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 21000000 * 10 ** decimals());
    }
}

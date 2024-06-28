// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface2_0.sol";
import "../Interface/KeeperRegistrarInterface.sol";
import "../Business/BusinessContract.sol";
import "../Users/Account.sol";

error REGISTERAUTOMATION__NOTOWNER();
error REGISTERAUTOMATION__NOTSHAKESCOUSER();

//Mainnet
contract ShakescoRegisterAutomation {
    LinkTokenInterface private linkToken;
    AutomationRegistryBaseInterface private s_registry;
    KeeperRegistrarInterface private s_registrar;
    mapping(address => uint256) private s_idToAddress;
    address payable private owner;

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert REGISTERAUTOMATION__NOTOWNER();
        }
        _;
    }

    modifier onlyShakescoUsers(address payable shakescoUser) {
        ShakescoAccount user = ShakescoAccount(shakescoUser);
        ShakescoBusinessContract business = ShakescoBusinessContract(
            shakescoUser
        );
        if (
            !user.isAuthorized(shakescoUser) ||
            !business.isAuthorized(shakescoUser)
        ) {
            revert REGISTERAUTOMATION__NOTSHAKESCOUSER();
        }
        _;
    }

    uint256[] private ids;

    constructor(
        address linkAddress,
        address registry,
        address registrar,
        address shakesco
    ) {
        linkToken = LinkTokenInterface(linkAddress);
        s_registry = AutomationRegistryBaseInterface(registry);
        s_registrar = KeeperRegistrarInterface(registrar);
        owner = payable(shakesco);
    }

    receive() external payable {}

    function register(
        RegistrationParams calldata requestParams
    ) external onlyShakescoUsers(payable(msg.sender)) {
        linkToken.approve(address(s_registrar), requestParams.amount);
        uint256 upkeepId = s_registrar.registerUpkeep(requestParams);
        if (upkeepId != 0) {
            ids.push(upkeepId);
            s_idToAddress[msg.sender] = upkeepId;
        } else {
            revert("auto-approve disabled");
        }
    }

    function fundIds(uint balance) external onlyOwner {
        uint len = ids.length;
        linkToken.approve(address(s_registry), balance);
        for (uint256 i = 0; i < len; ) {
            uint96 bal = s_registry.getUpkeep(ids[i]).balance;
            if (bal < 3e17) {
                s_registry.addFunds(ids[i], 1e18);
                unchecked {
                    ++i;
                }
            }
        }
    }

    function cancelId(uint256 id) external {
        s_registry.cancelUpkeep(id);
    }

    function pauseId(uint256 id) external {
        s_registry.pauseUpkeep(id);
    }

    function unPauseId(uint256 id) external {
        s_registry.unpauseUpkeep(id);
    }

    function editGasLimit(uint256 id, uint32 gasLimit) external {
        s_registry.setUpkeepGasLimit(id, gasLimit);
    }

    function changeAdmin(address proposed, uint256 id) external {
        s_registry.transferUpkeepAdmin(id, proposed);
    }

    function changeRegistry(address registry) external onlyOwner {
        s_registry = AutomationRegistryBaseInterface(registry);
    }

    function changeRegistrar(address registrar) external onlyOwner {
        s_registrar = KeeperRegistrarInterface(registrar);
    }

    function getIds() external view returns (uint256[] memory) {
        return ids;
    }

    function getIdByAddress(address caller) external view returns (uint256) {
        return s_idToAddress[caller];
    }

    function getBalanceById(address caller) external view returns (uint256) {
        return s_registry.getUpkeep(s_idToAddress[caller]).balance;
    }

    function fundById(uint96 bal) external {
        linkToken.approve(address(s_registry), bal);
        s_registry.addFunds(s_idToAddress[msg.sender], bal);
    }
}

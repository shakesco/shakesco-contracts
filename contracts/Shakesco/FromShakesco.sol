// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../Business/BusinessContract.sol";
import "../Users/Account.sol";

error FROMSHAKESPAY__NOTSHAKESPAY();
error FROMSHAKESPAY__NOTENOUGHFUNDS();
error FROMSHAKESPAY__TRANSACTIONFAILED();
error FROMSHAKESPAY__UPKEEPNOTNEEDED();
error FROMSHAKESPAY__NOTOPEN();
error FROMSHAKESPAY__ENTERED();
error FROMSHAKESPAY__OUTOFBOUND();
error FROMSHAKESPAY__NOTSHAKESCOUSER();

using SafeMath for uint256;
enum SavingState {
    OPEN,
    CALCULATING
}

/// @title Lottery like payouts for saving
/// @author Shawn Kimtai
/// @notice Earn money as you save
/// @dev This contract will allow people who have funded their saving
/// account to receive weekely rewards. Chainlink VRF helps us have
/// a random selection of all the participants and then we use AutomationCompatibleInterface
/// to automate the process.

contract FromShakespay is
    VRFConsumerBaseV2,
    AutomationCompatibleInterface,
    ReentrancyGuard
{
    address private i_shakespayOwner;
    address payable[] private s_participants;
    mapping(address => bool) private s_winner;
    address payable[] private winners;
    uint256 private s_shakescoproceeds;
    uint256 private s_winnerproceeds;
    SavingState private s_savingState;

    //vrf variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint256 private s_lastTimeStamp;
    uint256 private s_winnerResetTimeStamp;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subId;
    uint32 private immutable i_callBackGasLimit;
    uint32 private immutable i_interval;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;

    event Withdrawn(address indexed receiver, uint256 indexed amount);
    event FundForSaving(address indexed receiver, uint256 indexed amount);
    event PayForSaving(address indexed receiver, uint256 indexed amount);
    event WinnerRequested(uint256 indexed winner);

    modifier onlyShakespay() {
        if (i_shakespayOwner != msg.sender) {
            revert FROMSHAKESPAY__NOTSHAKESPAY();
        }
        _;
    }

    modifier onlyShakescoUsers(address payable saver) {
        ShakescoAccount account = ShakescoAccount(saver);
        ShakescoBusinessContract business = ShakescoBusinessContract(saver);
        if (!account.isAuthorized(saver) || !business.isAuthorized(saver)) {
            revert FROMSHAKESPAY__NOTSHAKESCOUSER();
        }
        _;
    }

    modifier onlyUnentered(address saver) {
        uint len = s_participants.length;
        for (uint i = 0; i < len; ) {
            if (saver == s_participants[i]) {
                remove(i);
                break;
            }
            unchecked {
                ++i;
            }
        }
        _;
    }

    constructor(
        address vrfCoordinator,
        bytes32 gasLane,
        uint32 callBackGasLimit,
        uint64 subId,
        address owner,
        uint32 interval
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_shakespayOwner = owner;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subId = subId;
        i_callBackGasLimit = callBackGasLimit;
        i_interval = interval;
        s_savingState = SavingState.OPEN;
        s_lastTimeStamp = block.timestamp;
        s_winnerResetTimeStamp = block.timestamp;
    }

    /**
     * @dev The following function helps shakespay to withdraw
     * from the contract
     * @param amount Amount shakespay wants to withdraw
     * @param withdrawAddress The address that shakespay wants to
     * withdraw to
     */

    function withdrawShakesPay(
        uint256 amount,
        address payable withdrawAddress
    ) external nonReentrant onlyShakespay {
        if (amount > s_shakescoproceeds) {
            revert FROMSHAKESPAY__NOTENOUGHFUNDS();
        }

        (bool success, ) = withdrawAddress.call{value: amount}("");
        if (!success) {
            revert FROMSHAKESPAY__TRANSACTIONFAILED();
        }
        emit Withdrawn(withdrawAddress, amount);
    }

    /**
     * @dev The function below will allow shakespay to pay the savings account if
     * and only if it saves some money in the account.
     * @dev It serves as a lottery like payout but for saving.
     * @dev Users that have won will not be able to win for another year.
     */

    function fundSavingForSaving(
        address payable shakescoUser
    )
        external
        payable
        onlyShakescoUsers(payable(msg.sender))
        onlyUnentered(shakescoUser)
    {
        if (s_savingState != SavingState.OPEN) {
            revert FROMSHAKESPAY__NOTOPEN();
        }

        s_winnerproceeds += msg.value;

        if (!s_winner[shakescoUser]) {
            s_participants.push(shakescoUser);
        }
    }

    /**
     * @dev The following function is automated by chainlink
     * to check if we need to perform upkeep or not.
     * @dev The following function will only return true if
     * 1 Time has passed
     * 2 There are people who have saved
     * 3 This contract has money
     */

    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasSavers = (s_participants.length > 0);
        bool hasMoney = (s_winnerproceeds > 0);
        upkeepNeeded = (timePassed && hasSavers && hasMoney);
        return (upkeepNeeded, "");
    }

    /**
     * @dev The following function performs upkeep by providing the
     * random number if and only if upkeep is needed.
     */

    function performUpkeep(bytes calldata /*performData*/) external override {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert FROMSHAKESPAY__UPKEEPNOTNEEDED();
        }

        s_savingState = SavingState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subId,
            REQUEST_CONFIRMATIONS,
            i_callBackGasLimit,
            NUM_WORDS
        );

        resetWinners();
        emit WinnerRequested(requestId);
    }

    /**
     * @dev The following functions picks a random winner from the
     * s_participants array and send them the reward because of saving.
     * @dev We then reset the array, make sure that they won't win for the
     * next year, reset the time and then pay them(Avoiding reentrant).
     */

    function fulfillRandomWords(
        uint256 /* requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 randomWinnerIndex = randomWords[0] % s_participants.length;
        address payable lastWinner = s_participants[randomWinnerIndex];

        uint fee = (s_winnerproceeds * 8) / 100;

        uint amount = s_winnerproceeds - fee;

        s_shakescoproceeds += fee;

        s_participants = new address payable[](0);
        winners.push(lastWinner);
        s_winner[lastWinner] = true;
        s_lastTimeStamp = block.timestamp;
        s_savingState = SavingState.OPEN;
        (bool success, ) = lastWinner.call{value: amount}("");
        if (!success) {
            revert FROMSHAKESPAY__TRANSACTIONFAILED();
        }
        emit PayForSaving(lastWinner, amount);
    }

    /**
     * @dev The following function is called after an year so that all the
     * previous winners can now again participate in the 'Lottery' like
     * saving contract.
     * */

    function resetWinners() private {
        if (block.timestamp < s_winnerResetTimeStamp + 182 days) {
            return;
        }

        uint256 len = winners.length;
        s_winnerResetTimeStamp = block.timestamp;
        for (uint256 i = 0; i < len; ) {
            if (s_winner[winners[i]]) {
                s_winner[winners[i]] = false;
            }
            unchecked {
                ++i;
            }
        }

        winners = new address payable[](0);
    }

    function changeOwner(address newOwner) external onlyShakespay {
        i_shakespayOwner = newOwner;
    }

    function getWinner(address isWinner) external view returns (bool) {
        return s_winner[isWinner];
    }

    function getNoOfSavers() external view returns (uint256) {
        return s_participants.length;
    }

    function getWinnerResetTimeStamp() external view returns (uint256) {
        return s_winnerResetTimeStamp;
    }

    function shakescoProceeds() external view returns (uint256) {
        return s_shakescoproceeds;
    }

    function winnerProceeds() external view returns (uint256) {
        return s_winnerproceeds;
    }

    function getLatestTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmation() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getVrfAddress() public view returns (VRFCoordinatorV2Interface) {
        return i_vrfCoordinator;
    }

    function getCallGasLimit() public view returns (uint32) {
        return i_callBackGasLimit;
    }

    function getGasLane() public view returns (bytes32) {
        return i_gasLane;
    }

    function getSubId() public view returns (uint64) {
        return i_subId;
    }

    function remove(uint _index) private {
        uint len = s_participants.length;
        if (_index > len) {
            revert FROMSHAKESPAY__OUTOFBOUND();
        }

        for (uint i = _index; i < len - 1; ) {
            s_participants[i] = s_participants[i + 1];
            unchecked {
                ++i;
            }
        }
        s_participants.pop();
    }
}

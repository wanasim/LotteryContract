// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Raffle Contract
 * @author Walid Nasim
 * @notice Contract for creating raffle
 * @dev Implements Chainlink VRF v2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /**
     * Type Declarations
     */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**
     * State Variables
     */
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash; // Gas Price Limit. Functions as an ID for the offchain VRF job
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp;
    address payable private s_winner;
    address payable[] private s_players;
    RaffleState private s_raffleState;

    error Raffle_NotEnoughEthSent();
    error Raffle_TransferFailed();
    error Raffle_StateNotOpen();
    error Raffle_UpkeepNotNeeded(uint256 raffleState);

    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed player);
    event RequestedRaffleWinner(uint256 requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH");
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_StateNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev Function the Chainlink Keeper nodes call
     * When `upkeepNeeded` returns True it'll invoke the performUpkeep callback
     * The following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. There are players registered.
     * 5. Implicitly, your subscription is funded with LINK.
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }

        bool hasTimePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool hasETH = address(this).balance > 0;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = hasTimePassed && hasETH && isOpen && hasPlayers;
        return (upkeepNeeded, hex"");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        // if (block.timestamp - s_lastTimeStamp >= i_interval) {
        //     revert();
        // }
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            console.log("REVERTING?@");
            revert Raffle_UpkeepNotNeeded(uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        /**
         * Get Random Number
         * 1. Request RNG
         * 2. Get Random Number
         */
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        console.log("REQUEST!!LKSVDFSD#@$@$", requestId);
        emit RequestedRaffleWinner(requestId);
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        // Pick Winner
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_winner = winner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_winner);

        (bool success,) = s_winner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle_TransferFailed();
        }
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getTimestamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getPlayers(uint256 index) external view returns (address) {
        // address matchedPlayer;
        // for (uint256 i = 0; i < s_players.length; i++) {
        //     if (s_players[i] == player) {
        //         matchedPlayer = s_players[i];
        //     }
        // }

        // return matchedPlayer;
        return s_players[index];
    }

    function getRecentWinner() external view returns (address) {
        return s_winner;
    }
}

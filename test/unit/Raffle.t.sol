// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from
    "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 interval;
    uint256 entranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinator;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        interval = config.interval;
        entranceFee = config.entranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinator;
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, 10 ether);
        raffle.enterRaffle{value: 1 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // not necessary
        _;
    }

    function testRaffleInitializesOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnterRaffleNotEnoughEth() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testEnterRafflePlayersUpdated() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, 10 ether);
        raffle.enterRaffle{value: 1 ether}();
        assert(raffle.getPlayers(0) == PLAYER);
    }

    function testEnterRaffleEvent() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, 10 ether);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: 1 ether}();
    }

    function testPreventPlayersToEnter() public raffleEntered {
        raffle.performUpkeep(hex"");

        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_StateNotOpen.selector);
        raffle.enterRaffle{value: 1 ether}();
    }

    function testCheckUpkeepIsFalse() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // not necessary

        (bool upkeepNeeded,) = raffle.checkUpkeep(hex"");

        assert(!upkeepNeeded);
    }

    function testEmitRaffle_UpkeepNotNeeded() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, 10 ether);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // not necessary
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_UpkeepNotNeeded.selector, raffle.getRaffleState()));
        raffle.performUpkeep("");
    }

    /**
     * Fuz Test
     */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered {
        // Arrange, Act, Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }
}

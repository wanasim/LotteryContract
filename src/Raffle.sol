// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Raffle Contract
 * @author Walid Nasim
 * @notice Contract for creating raffle
 * @dev Implements Chainlink VRF v2.5
 */
contract Raffle {
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    error Raffle_NotEnoughEthSent();

    event EnteredRaffle(address indexed player);

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaflle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH");
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {}

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}

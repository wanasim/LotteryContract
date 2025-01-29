// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from
    "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {LinkToken} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    address public FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    address constant DEV_SEPOLIA_ACCOUNT = 0xbab69B1303FD3121285D7b9e1B8205680Ec832a7;
    address constant DEV_LOCAL_ACCOUNT = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
}

contract HelperConfig is CodeConstants, Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address link;
        address account;
    }

    NetworkConfig public config;
    mapping(uint256 chainId => NetworkConfig) private configs;

    error HelperConfig__InvalidChainID(uint256 chainId);

    constructor() {
        configs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        // configs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
        // Note: We skip doing the local config
    }

    function getConfig() external returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (configs[chainId].vrfCoordinator != address(0)) {
            return configs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainID(chainId);
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether, // 1e16
            interval: 30, // 30 seconds
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, // 500,000 gas
            subscriptionId: 39859582699544798846441225442176155736163730660082377416680044829239494045349, // this will be the subscriptionId generated from Chainlink VRF UI
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: CodeConstants.DEV_SEPOLIA_ACCOUNT
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        /**
         * return current config if it exists
         */
        if (config.vrfCoordinator != address(0)) {
            return config;
        }

        /**
         * Deploy mock coordinator for local Anvil
         */
        console.log("networkconfig accon!@#t", config.account);
        vm.startBroadcast(CodeConstants.DEV_LOCAL_ACCOUNT);
        VRFCoordinatorV2_5Mock mockCoordinator =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);

        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        /**
         * update and return config
         */
        config = NetworkConfig({
            entranceFee: 0.01 ether, // 1e16
            interval: 30, // 30 seconds
            vrfCoordinator: address(mockCoordinator),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // doesn't matter
            callbackGasLimit: 500000, // 500,000 gas
            subscriptionId: 0,
            link: address(linkToken),
            account: CodeConstants.DEV_LOCAL_ACCOUNT // Default msg.sender & tx.origin for Foundry
        });

        return config;
    }
}

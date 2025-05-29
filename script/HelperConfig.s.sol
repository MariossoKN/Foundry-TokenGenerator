// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Script} from "../lib/forge-std/src/Script.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        uint256 fee;
        uint256 deployerKey;
        uint256 icoDeadlineInDays;
        address uniswapV2FactoryAddress;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainNetEthConfig();
        } else {
            activeNetworkConfig = getAnvilEthConfig();
        }
    }

    function getMainNetEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory mainNetNetworkConfig = NetworkConfig({
            fee: 1000000000000000, // 0.001 ETH
            deployerKey: vm.envUint("PRIVATE_KEY"),
            icoDeadlineInDays: 30,
            uniswapV2FactoryAddress: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        });
        return mainNetNetworkConfig;
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaNetworkConfig = NetworkConfig({
            fee: 1000000000000000, // 0.001 ETH
            deployerKey: vm.envUint("PRIVATE_KEY"),
            icoDeadlineInDays: 30,
            uniswapV2FactoryAddress: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        });
        return sepoliaNetworkConfig;
    }

    function getAnvilEthConfig() public pure returns (NetworkConfig memory) {
        // vm.createSelectFork(
        //     "https://eth-mainnet.g.alchemy.com/v2/eoyW9TYqjQcaulRU3IsmUrrALOjFg5_e"
        // );

        NetworkConfig memory anvilNetworkConfig = NetworkConfig({
            fee: 1000000000000000, // 0.001 ETH
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY,
            icoDeadlineInDays: 30,
            uniswapV2FactoryAddress: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        });
        return anvilNetworkConfig;
    }
}

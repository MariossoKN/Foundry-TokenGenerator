// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Script} from "../lib/forge-std/src/Script.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {WETH} from "../script/MockWETH.s.sol";
import {StdCheats} from "../../lib/forge-std/src/Test.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Router02 public uniswapV2Router;
    WETH mockWeth;

    struct NetworkConfig {
        uint256 fee;
        address account;
        uint256 icoDeadlineInDays;
        address uniswapV2FactoryAddress;
        address uniswapV2RouterAddress;
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

    function getMainNetEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainNetNetworkConfig = NetworkConfig({
            fee: 1000000000000000, // 0.001 ETH
            account: 0x8F2c4E4aF8D7be5878468559a7a032C5887e2D33,
            icoDeadlineInDays: 30,
            uniswapV2FactoryAddress: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
            uniswapV2RouterAddress: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        });
        return mainNetNetworkConfig;
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaNetworkConfig = NetworkConfig({
            fee: 1000000000000000, // 0.001 ETH
            account: 0x8F2c4E4aF8D7be5878468559a7a032C5887e2D33,
            icoDeadlineInDays: 30,
            uniswapV2FactoryAddress: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
            uniswapV2RouterAddress: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        });
        return sepoliaNetworkConfig;
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        // vm.createSelectFork(
        //     "https://eth-mainnet.g.alchemy.com/v2/eoyW9TYqjQcaulRU3IsmUrrALOjFg5_e"
        // );

        uniswapV2Factory = IUniswapV2Factory(
            deployCode(
                "./out/UniswapV2Factory.sol/UniswapV2Factory.json",
                abi.encode(555555555555555)
            )
        );

        mockWeth = new WETH();

        uniswapV2Router = IUniswapV2Router02(
            deployCode(
                "./out/UniswapV2Router02.sol/UniswapV2Router02.json",
                abi.encode(address(uniswapV2Factory), address(mockWeth))
            )
        );

        NetworkConfig memory anvilNetworkConfig = NetworkConfig({
            fee: 1000000000000000, // 0.001 ETH
            account: 0x8F2c4E4aF8D7be5878468559a7a032C5887e2D33,
            icoDeadlineInDays: 30,
            uniswapV2FactoryAddress: address(uniswapV2Factory),
            uniswapV2RouterAddress: address(uniswapV2Router)
            // uniswapV2FactoryAddress: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
            // uniswapV2RouterAddress: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        });
        return anvilNetworkConfig;
    }
}

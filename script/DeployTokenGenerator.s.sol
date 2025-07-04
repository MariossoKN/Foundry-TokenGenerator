// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Script} from "../lib/forge-std/src/Script.sol";
import {TokenGenerator} from "../src/TokenGenerator.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployTokenGenerator is Script {
    TokenGenerator public tokenGenerator;
    HelperConfig public helperConfig;

    function run() external returns (TokenGenerator, HelperConfig) {
        helperConfig = new HelperConfig();
        (
            uint256 fee,
            address account,
            uint256 icoDeadlineInDays,
            address uniswapV2FactoryAddress,
            address uniswapV2RouterAddress
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(account);
        tokenGenerator = new TokenGenerator(
            fee,
            icoDeadlineInDays,
            uniswapV2FactoryAddress,
            uniswapV2RouterAddress
        );
        vm.stopBroadcast();
        return (tokenGenerator, helperConfig);
    }
}

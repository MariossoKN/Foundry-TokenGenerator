// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

import {DeployTokenGenerator} from "../script/DeployTokenGenerator.s.sol";
import {TokenGenerator} from "../src/TokenGenerator.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

contract TestTokenGenerator is Test {
    TokenGenerator public tokenGenerator;
    HelperConfig public helperConfig;

    uint256 public fee;
    uint256 deployerKey;

    address TOKEN_GENERATOR_OWNER = makeAddr("tokenGeneratorOwner");
    address INVESTOR = makeAddr("investor");
    address INVESTOR2 = makeAddr("investor2");
    address INVESTOR3 = makeAddr("investor3");
    uint256 STARTING_BALANCE = 100 ether;

    string PROJECT_NAME = "Happy Token";
    string PROJECT_SYMBOL = "HTK";
    uint256 TOKEN_SUPPLY = 1000000 ether;
    uint256 INVESTMENT_ONE = 5 ether;
    uint256 INVESTMENT_TWO = 50 ether;

    function setUp() external {
        DeployTokenGenerator deployTokenGenerator = new DeployTokenGenerator();
        (tokenGenerator, helperConfig) = deployTokenGenerator.run();
        (fee, deployerKey) = helperConfig.activeNetworkConfig();

        vm.deal(TOKEN_GENERATOR_OWNER, STARTING_BALANCE * 5);
        vm.deal(INVESTOR, STARTING_BALANCE);
        vm.deal(INVESTOR2, STARTING_BALANCE);
        vm.deal(INVESTOR3, STARTING_BALANCE);
    }

    //////////////////////
    // helper functions //
    //////////////////////

    //////////////////////
    // constructor TEST //
    //////////////////////
    function testConstructorParametersShouldBeInitializedCorrectly()
        public
        view
    {
        assertEq(tokenGenerator.getFees(), fee);
    }

    /////////////////////////
    // createProject TESTs //
    /////////////////////////
}

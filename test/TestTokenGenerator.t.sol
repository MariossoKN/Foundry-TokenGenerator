// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

import {DeployTokenGenerator} from "../script/DeployTokenGenerator.s.sol";
import {TokenGenerator} from "../src/TokenGenerator.sol";
import {Token} from "../src/Token.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

contract TestTokenGenerator is Test {
    event TokenCreated(
        address indexed tokenAddress,
        uint256 indexed tokenSupply,
        address indexed tokenCreator
    );

    TokenGenerator public tokenGenerator;
    HelperConfig public helperConfig;

    uint256 public fee;
    uint256 deployerKey;

    address TOKEN_GENERATOR_OWNER = makeAddr("tokenGeneratorOwner");
    address TOKEN_OWNER = makeAddr("tokenOwner");
    address INVESTOR = makeAddr("investor");
    address INVESTOR2 = makeAddr("investor2");
    address INVESTOR3 = makeAddr("investor3");
    uint256 STARTING_BALANCE = 100 ether;

    string TOKEN_NAME = "Happy Token";
    string TOKEN_SYMBOL = "HTK";
    uint256 TOKEN_SUPPLY = 1000000 ether;
    uint256 TOKEN_FUND_GOAL = 1000 ether;
    uint256 INCORRECT_FUND_GOAL = 99 ether;
    uint256 INVESTMENT_ONE = 5 ether;
    uint256 INVESTMENT_TWO = 50 ether;

    function setUp() external {
        DeployTokenGenerator deployTokenGenerator = new DeployTokenGenerator();
        (tokenGenerator, helperConfig) = deployTokenGenerator.run();
        (fee, deployerKey) = helperConfig.activeNetworkConfig();

        vm.deal(TOKEN_GENERATOR_OWNER, STARTING_BALANCE * 5);
        vm.deal(TOKEN_OWNER, STARTING_BALANCE * 5);
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

    ///////////////////////
    // createToken TESTs //
    ///////////////////////
    function testFuzz_ShouldRevertIfValueSentIsLessThanFee(
        uint256 _amount
    ) public {
        uint256 amount = bound(_amount, 1, fee - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ValueSentIsLow.selector
            )
        );
        tokenGenerator.createToken{value: amount}(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_SUPPLY,
            TOKEN_FUND_GOAL
        );
    }

    function testFuzz_ShouldRevertIfFundGoalIsLow(uint256 _amount) public {
        uint256 amount = bound(_amount, 1, INCORRECT_FUND_GOAL);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__FundGoalTooLow.selector
            )
        );
        tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_SUPPLY,
            amount
        );
    }

    function testShouldCreateAnewTokenContract() public {
        vm.prank(TOKEN_OWNER);
        tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_SUPPLY,
            TOKEN_FUND_GOAL
        );

        address token = tokenGenerator.getToken(0);

        string memory tokenName = Token(token).name();
        string memory tokenSymbol = Token(token).symbol();
        uint256 tokenSupply = Token(token).totalSupply();
        address tokenCreator = Token(token).getTokenCreator();

        assertEq(tokenName, TOKEN_NAME);
        assertEq(tokenSymbol, TOKEN_SYMBOL);
        assertEq(tokenSupply, TOKEN_SUPPLY);
        assertEq(tokenCreator, TOKEN_OWNER);
    }

    function testShouldUpdateTokenDataCorrectly() public {
        vm.prank(TOKEN_OWNER);
        tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_SUPPLY,
            TOKEN_FUND_GOAL
        );

        address token = tokenGenerator.getToken(0);

        address creator = tokenGenerator.getTokenCreator(token);
        uint256 fundGoal = tokenGenerator.getTokenFundGoal(token);
        uint256 tokensSold = tokenGenerator.getTokenTokensSold(token);

        assertEq(creator, TOKEN_OWNER);
        assertEq(fundGoal, TOKEN_FUND_GOAL);
        assertEq(tokensSold, 0);
    }

    function testShouldEmitEventAfterCreatingToken() public {
        vm.prank(TOKEN_OWNER);
        vm.expectEmit(true, true, true, false);
        emit TokenCreated(
            address(0xa16E02E87b7454126E5E10d957A927A7F5B5d2be),
            TOKEN_SUPPLY,
            TOKEN_OWNER
        );
        tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_SUPPLY,
            TOKEN_FUND_GOAL
        );
    }
}

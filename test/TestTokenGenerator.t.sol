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

    event TokenBuy(
        address indexed tokenAddress,
        uint256 indexed tokenAmountBought,
        address buyer
    );

    TokenGenerator public tokenGenerator;
    HelperConfig public helperConfig;

    uint256 public fee;
    uint256 deployerKey;

    address tokenAddress;

    uint256 STARTING_INCREMENT = 0.0001 ether; // change if defined differently in the TokenGenerator contract
    uint256 INCREMENT_TWO = STARTING_INCREMENT * 2;
    uint256 INCREMENT_THREE = STARTING_INCREMENT * 3;

    address TOKEN_GENERATOR_OWNER = makeAddr("tokenGeneratorOwner");
    address TOKEN_OWNER = makeAddr("tokenOwner");
    address BUYER = makeAddr("buyer");
    address BUYER2 = makeAddr("buyer2");
    address BUYER3 = makeAddr("buyer3");
    address BUYER4 = makeAddr("buyer4");
    uint256 STARTING_BALANCE = 100 ether;

    string TOKEN_NAME = "Happy Token";
    string TOKEN_SYMBOL = "HTK";
    uint256 TOKEN_SUPPLY = 1000000 ether;
    uint256 TOKEN_FUND_GOAL = 100 ether;
    uint256 INCORRECT_FUND_GOAL = 99 ether;

    uint256 TOKEN_AMOUNT_ONE = 10200 ether;
    uint256 TOKEN_AMOUNT_TWO = 22500 ether;
    uint256 TOKEN_AMOUNT_THREE = 55200 ether;
    uint256 TOKEN_AMOUNT_FOUR = 105000 ether;

    function setUp() external {
        DeployTokenGenerator deployTokenGenerator = new DeployTokenGenerator();
        (tokenGenerator, helperConfig) = deployTokenGenerator.run();
        (fee, deployerKey) = helperConfig.activeNetworkConfig();

        vm.deal(TOKEN_GENERATOR_OWNER, STARTING_BALANCE * 5);
        vm.deal(TOKEN_OWNER, STARTING_BALANCE * 5);
        vm.deal(BUYER, STARTING_BALANCE);
        vm.deal(BUYER2, STARTING_BALANCE);
        vm.deal(BUYER3, STARTING_BALANCE);
        vm.deal(BUYER4, STARTING_BALANCE);
    }

    //////////////////////
    // helper functions //
    //////////////////////
    function createToken() public {
        vm.prank(TOKEN_OWNER);

        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);

        tokenAddress = tokenGenerator.getTokenAddress(0);
    }

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
        tokenGenerator.createToken{value: amount}(TOKEN_NAME, TOKEN_SYMBOL);
    }

    function testShouldCreateAnewTokenContract() public {
        vm.prank(TOKEN_OWNER);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);

        address newToken = tokenGenerator.getTokenAddress(0);

        string memory tokenName = Token(newToken).name();
        string memory tokenSymbol = Token(newToken).symbol();
        uint256 tokenSupply = Token(newToken).totalSupply();
        address tokenCreator = Token(newToken).getTokenCreator();

        assertEq(tokenName, TOKEN_NAME);
        assertEq(tokenSymbol, TOKEN_SYMBOL);
        assertEq(tokenSupply, TOKEN_SUPPLY);
        assertEq(tokenCreator, TOKEN_OWNER);
    }

    function testShouldUpdateTokenDataCorrectly() public {
        vm.prank(TOKEN_OWNER);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);

        address newToken = tokenGenerator.getTokenAddress(0);

        address creator = tokenGenerator.getTokenCreator(newToken);

        assertEq(creator, TOKEN_OWNER);
    }

    function testShouldEmitEventAfterCreatingToken() public {
        vm.prank(TOKEN_OWNER);
        vm.expectEmit(true, true, true, false);
        emit TokenCreated(
            address(0xa16E02E87b7454126E5E10d957A927A7F5B5d2be),
            TOKEN_SUPPLY,
            TOKEN_OWNER
        );
        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);
    }

    ////////////////////
    // buyToken TESTs //
    ////////////////////
    // function testShouldRevertIfWrongAddressIsProvided() public {
    //     createToken();

    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             TokenGenerator.TokenGenerator__WrongTokenAddress.selector
    //         )
    //     );
    //     tokenGenerator.buyToken{value: tokenCost}(
    //         TOKEN_OWNER,
    //         TOKEN_AMOUNT_ONE
    //     );
    // }

    // function testShouldRevertIfTokenAmountIsZero() public {
    //     createToken();

    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             TokenGenerator.TokenGenerator__TokenAmountTooLow.selector
    //         )
    //     );
    //     tokenGenerator.buyToken{value: tokenCost}(tokenAddress, 0);
    // }

    // function testShouldRevertIfFundGoalAlreadyRaised() public {
    //     createToken();

    //     // buyer one ~ 21 ETH
    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR * 2
    //     );

    //     vm.prank(BUYER);
    //     tokenGenerator.buyToken{value: tokenCost}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR * 2
    //     );

    //     // buyer two ~ 63 ETH
    //     uint256 tokenCostTwo = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR * 2
    //     );

    //     vm.prank(BUYER2);
    //     tokenGenerator.buyToken{value: tokenCostTwo}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR * 2
    //     );

    //     // buyer three ~ 126 ETH
    //     uint256 tokenCostThree = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR * 2
    //     );

    //     vm.prank(BUYER3);
    //     tokenGenerator.buyToken{value: tokenCostThree}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR * 2
    //     );

    //     // buyer four (exceeding the goal)
    //     uint256 tokenCostFour = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     vm.prank(BUYER4);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             TokenGenerator.TokenGenerator__AmountExceedsTheFundGoal.selector
    //         )
    //     );
    //     tokenGenerator.buyToken{value: tokenCostFour}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );
    // }

    // function testFuzz_ShouldRevertIfAmountSentIsLow(uint256 _amount) public {
    //     createToken();

    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );

    //     uint256 incorrectTokenCost = bound(_amount, 1, tokenCost - 1);

    //     vm.prank(BUYER);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             TokenGenerator.TokenGenerator__ValueSentWrong.selector,
    //             tokenCost
    //         )
    //     );
    //     tokenGenerator.buyToken{value: incorrectTokenCost}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );
    // }

    // function testShouldUpdateTheSalesForTheToken() public {
    //     createToken();

    //     // buy #1
    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );

    //     vm.prank(BUYER);
    //     tokenGenerator.buyToken{value: tokenCost}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );

    //     // buy #2
    //     uint256 tokenCostTwo = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_TWO
    //     );

    //     vm.prank(BUYER2);
    //     tokenGenerator.buyToken{value: tokenCostTwo}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_TWO
    //     );

    //     // buy #3
    //     uint256 tokenCostThree = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     vm.prank(BUYER2);
    //     tokenGenerator.buyToken{value: tokenCostThree}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );
    // }

    // function testShouldSendEthToTheTokenContract() public {
    //     createToken();

    //     assertEq(tokenAddress.balance, 0);

    //     // buy #1
    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );

    //     vm.prank(BUYER);
    //     tokenGenerator.buyToken{value: tokenCost}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );

    //     assertEq(tokenAddress.balance, tokenCost);

    //     // buy #2
    //     uint256 tokenCostTwo = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_TWO
    //     );

    //     vm.prank(BUYER2);
    //     tokenGenerator.buyToken{value: tokenCostTwo}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_TWO
    //     );

    //     assertEq(tokenAddress.balance, tokenCost + tokenCostTwo);

    //     // buy #3
    //     uint256 tokenCostThree = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     vm.prank(BUYER2);
    //     tokenGenerator.buyToken{value: tokenCostThree}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     assertEq(
    //         tokenAddress.balance,
    //         tokenCost + tokenCostTwo + tokenCostThree
    //     );
    // }

    // function testShouldSendTheTokensAmountToTheBuyer() public {
    //     createToken();

    //     // buy #1
    //     assertEq(Token(tokenAddress).balanceOf(BUYER), 0);

    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );

    //     vm.prank(BUYER);
    //     tokenGenerator.buyToken{value: tokenCost}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );

    //     assertEq(Token(tokenAddress).balanceOf(BUYER), TOKEN_AMOUNT_FOUR);

    //     // buy #2
    //     assertEq(Token(tokenAddress).balanceOf(BUYER2), 0);

    //     uint256 tokenCostTwo = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_TWO
    //     );

    //     vm.prank(BUYER2);
    //     tokenGenerator.buyToken{value: tokenCostTwo}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_TWO
    //     );

    //     assertEq(Token(tokenAddress).balanceOf(BUYER2), TOKEN_AMOUNT_TWO);

    //     // buy #3
    //     assertEq(Token(tokenAddress).balanceOf(BUYER3), 0);

    //     uint256 tokenCostThree = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     vm.prank(BUYER3);
    //     tokenGenerator.buyToken{value: tokenCostThree}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     assertEq(Token(tokenAddress).balanceOf(BUYER3), TOKEN_AMOUNT_ONE);
    // }

    // function testShouldEmitAnEvent() public {
    //     createToken();

    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );

    //     vm.prank(BUYER);
    //     vm.expectEmit(true, true, true, false);
    //     emit TokenBuy(tokenAddress, TOKEN_AMOUNT_FOUR, BUYER);

    //     tokenGenerator.buyToken{value: tokenCost}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_FOUR
    //     );
    // }

    // ///////////////////////////////
    // // calculateTokenCost TESTs //
    // ///////////////////////////////
    // function testShouldCalculatePriceOfTokensWithZeroPurchases() public {
    //     createToken();

    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     assertEq(STARTING_INCREMENT * (TOKEN_AMOUNT_ONE / 10 ** 18), tokenCost);
    // }

    // function testShouldCalculatePriceOfTokensWithMultiplePurchases() public {
    //     createToken();

    //     // purchase #1
    //     uint256 tokenCost = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     assertEq(STARTING_INCREMENT * (TOKEN_AMOUNT_ONE / 10 ** 18), tokenCost);

    //     vm.prank(BUYER);
    //     tokenGenerator.buyToken{value: tokenCost}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     // purchase #2
    //     uint256 tokenCostTwo = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     assertEq(INCREMENT_TWO * (TOKEN_AMOUNT_ONE / 10 ** 18), tokenCostTwo);

    //     vm.prank(BUYER2);
    //     tokenGenerator.buyToken{value: tokenCostTwo}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     // purchase #3
    //     uint256 tokenCostThree = tokenGenerator.calculateTokenCost(
    //         tokenAddress,
    //         TOKEN_AMOUNT_TWO
    //     );

    //     assertEq(
    //         INCREMENT_THREE * (TOKEN_AMOUNT_TWO / 10 ** 18),
    //         tokenCostThree
    //     );

    //     vm.prank(BUYER3);
    //     tokenGenerator.buyToken{value: tokenCostThree}(
    //         tokenAddress,
    //         TOKEN_AMOUNT_TWO
    //     );
    // }

    ////////////////////////////
    // getTokenFundGoal TESTs //
    ////////////////////////////

    // calculate cost TEST

    function testCalculateCost() public {
        createToken();

        uint256 initialSupply = tokenGenerator.getInitialSupply();
        uint256 currentSupply = (Token(tokenAddress).totalSupply()) -
            initialSupply;

        console.log(currentSupply);

        uint256 tokenCost = tokenGenerator.calculateTokenCost(
            currentSupply,
            500 // 125 is minimum?
        );
        console.log(tokenCost);
    }

    function testCalculatePrice() public {
        createToken();

        uint256 initialSupply = tokenGenerator.getInitialSupply();
        uint256 currentSupply = (Token(tokenAddress).totalSupply()) -
            initialSupply;

        console.log(currentSupply);

        uint256 tokenCost = tokenGenerator.calculatePrice(100000 ether);
        console.log(tokenCost);
    }

    //              //

    function testBuyTokenWithOneUser() public {
        createToken();

        uint256 currentSupply = tokenGenerator.getCurrentSupply(tokenAddress);
        assertEq(currentSupply, 0);

        uint256 balanceOfTokenContract = Token(tokenAddress).balanceOf(
            tokenAddress
        );
        assertEq(balanceOfTokenContract, 0);

        uint256 tokenAmount = 200000;

        uint256 tokensPrice = tokenGenerator.calculatePriceForTokens(
            tokenAddress,
            tokenAmount
        );

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: tokensPrice}(tokenAddress, tokenAmount);

        uint256 newCurrentSupply = tokenGenerator.getCurrentSupply(
            tokenAddress
        );
        assertEq(newCurrentSupply, tokenAmount);

        uint256 newBalanceOfTokenContract = Token(tokenAddress).balanceOf(
            tokenAddress
        );
        assertEq(newBalanceOfTokenContract, tokenAmount);
    }

    function testBuyTokenWithMultipleUsers() public {
        createToken();

        uint256 tokenAmountOne = 50000;
        uint256 tokenAmountTwo = 125000;
        uint256 tokenAmountThree = 25000;

        // Buyer 1
        uint256 tokensPriceOne = tokenGenerator.calculatePriceForTokens(
            tokenAddress,
            tokenAmountOne
        );

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: tokensPriceOne}(
            tokenAddress,
            tokenAmountOne
        );

        uint256 currentSupplyOne = tokenGenerator.getCurrentSupply(
            tokenAddress
        );
        assertEq(currentSupplyOne, tokenAmountOne);

        uint256 balanceOfTokenContractOne = Token(tokenAddress).balanceOf(
            tokenAddress
        );
        assertEq(balanceOfTokenContractOne, tokenAmountOne);

        assertEq(tokenGenerator.getTokenStage(tokenAddress), 0);

        // Buyer 2
        uint256 tokensPriceTwo = tokenGenerator.calculatePriceForTokens(
            tokenAddress,
            tokenAmountTwo
        );

        vm.prank(BUYER2);
        tokenGenerator.buyToken{value: tokensPriceTwo}(
            tokenAddress,
            tokenAmountTwo
        );

        uint256 currentSupplyTwo = tokenGenerator.getCurrentSupply(
            tokenAddress
        );
        assertEq(currentSupplyTwo, tokenAmountOne + tokenAmountTwo);

        uint256 balanceOfTokenContractTwo = Token(tokenAddress).balanceOf(
            tokenAddress
        );
        assertEq(balanceOfTokenContractTwo, tokenAmountOne + tokenAmountTwo);

        assertEq(tokenGenerator.getTokenStage(tokenAddress), 0);

        // Buyer 3
        uint256 tokensPriceThree = tokenGenerator.calculatePriceForTokens(
            tokenAddress,
            tokenAmountThree
        );

        vm.prank(BUYER3);
        tokenGenerator.buyToken{value: tokensPriceThree}(
            tokenAddress,
            tokenAmountThree
        );

        uint256 currentSupplyThree = tokenGenerator.getCurrentSupply(
            tokenAddress
        );
        assertEq(
            currentSupplyThree,
            tokenAmountOne + tokenAmountTwo + tokenAmountThree
        );

        uint256 balanceOfTokenContractThree = Token(tokenAddress).balanceOf(
            tokenAddress
        );
        assertEq(
            balanceOfTokenContractThree,
            tokenAmountOne + tokenAmountTwo + tokenAmountThree
        );

        assertEq(tokenGenerator.getTokenStage(tokenAddress), 1);
    }

    function testCalculateTokensPrice() public {
        createToken();

        uint256 tokensPrice = tokenGenerator.calculatePriceForTokens(
            tokenAddress,
            50000
        );

        console.log("Tokens price: ", tokensPrice);
    }

    function testGetCurrentSupply() public {
        createToken();

        uint256 currentSupply = tokenGenerator.getCurrentSupply(tokenAddress);

        console.log("Current supply: ", currentSupply);
    }

    function testGetStagePrice() public {
        createToken();

        uint256 tokenStage = tokenGenerator.getTokenStage(tokenAddress);

        uint256 stagePrice = tokenGenerator.getStagePrice(tokenStage);

        console.log("Stage price: ", stagePrice);
    }

    function testGetTokenStage() public {
        createToken();

        uint256 tokenStage = tokenGenerator.getTokenStage(tokenAddress);

        console.log("Token stage: ", tokenStage);
    }

    function testGetAvailableSupply() public {
        createToken();

        uint256 availableSupply = tokenGenerator.getAvailableStageSupply(
            tokenAddress
        );

        console.log("Available supply: ", availableSupply);
    }
}

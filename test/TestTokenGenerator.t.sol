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

    uint256 ONE_DAY_IN_SECONDS = 86400;
    uint256 DEADLINE_IN_DAYS = 30;

    address TOKEN_GENERATOR_OWNER = makeAddr("tokenGeneratorOwner");
    address TOKEN_OWNER = makeAddr("tokenOwner");
    address TOKEN_OWNER2 = makeAddr("tokenOwner2");
    address TOKEN_OWNER3 = makeAddr("tokenOwner3");
    address BUYER = makeAddr("buyer");
    address BUYER2 = makeAddr("buyer2");
    address BUYER3 = makeAddr("buyer3");
    address BUYER4 = makeAddr("buyer4");
    uint256 STARTING_BALANCE = 100 ether;

    string TOKEN_NAME = "Happy Token";
    string TOKEN_SYMBOL = "HTK";
    string TOKEN_NAME2 = "Smile Token";
    string TOKEN_SYMBOL2 = "STK";
    string TOKEN_NAME3 = "Monkey Token";
    string TOKEN_SYMBOL3 = "MTK";
    string TOKEN_NAME4 = "Dark Token";
    string TOKEN_SYMBOL4 = "DTK";
    uint256 INITIAL_TOKEN_SUPPLY = 200000;
    uint256 TOKEN_FUND_GOAL = 100 ether;
    uint256 INCORRECT_FUND_GOAL = 99 ether;

    uint256 TOKEN_AMOUNT_ONE = 50000;
    uint256 TOKEN_AMOUNT_TWO = 100000;
    uint256 TOKEN_AMOUNT_THREE = 200000;
    uint256 TOKEN_AMOUNT_FOUR = 125000;

    function setUp() external {
        DeployTokenGenerator deployTokenGenerator = new DeployTokenGenerator();
        (tokenGenerator, helperConfig) = deployTokenGenerator.run();
        (fee, deployerKey) = helperConfig.activeNetworkConfig();

        vm.deal(TOKEN_GENERATOR_OWNER, STARTING_BALANCE * 5);
        vm.deal(TOKEN_OWNER, STARTING_BALANCE * 5);
        vm.deal(TOKEN_OWNER2, STARTING_BALANCE * 5);
        vm.deal(TOKEN_OWNER3, STARTING_BALANCE * 5);
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

    function createTokenAndBuyAmountOneTokens() public {
        createToken();

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_ONE);
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
        uint256 amount = bound(_amount, 0, fee - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ValueSentIsLow.selector,
                fee
            )
        );
        tokenGenerator.createToken{value: amount}(TOKEN_NAME, TOKEN_SYMBOL);
    }

    function testShouldCreateAnewTokenContractSingleToken() public {
        vm.prank(TOKEN_OWNER);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);

        address newTokenAddress = tokenGenerator.getTokenAddress(0);

        string memory tokenName = Token(newTokenAddress).name();
        string memory tokenSymbol = Token(newTokenAddress).symbol();
        uint256 tokenSupply = Token(newTokenAddress).totalSupply();
        address tokenCreator = Token(newTokenAddress).getTokenCreator();

        assertEq(tokenName, TOKEN_NAME);
        assertEq(tokenSymbol, TOKEN_SYMBOL);
        assertEq(tokenSupply, tokenGenerator.getInitialSupply());
        assertEq(
            tokenCreator,
            tokenGenerator.getTokenCreatorAddress(newTokenAddress)
        );
    }

    // function testShouldCreateAnewTokenContractMultipleTokens() public {
    //     // Create tokens
    //     vm.prank(TOKEN_OWNER);
    //     tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);
    //     vm.prank(TOKEN_OWNER2);
    //     tokenGenerator.createToken{value: fee}(TOKEN_NAME2, TOKEN_SYMBOL2);
    //     vm.prank(TOKEN_OWNER2);
    //     tokenGenerator.createToken{value: fee}(TOKEN_NAME3, TOKEN_SYMBOL3);
    //     vm.prank(TOKEN_OWNER3);
    //     tokenGenerator.createToken{value: fee}(TOKEN_NAME4, TOKEN_SYMBOL4);

    //     // Check first token
    //     address newTokenAddress = tokenGenerator.getTokenAddress(0);
    //     assertEq(Token(newTokenAddress).name(), TOKEN_NAME);
    //     assertEq(Token(newTokenAddress).symbol(), TOKEN_SYMBOL);
    //     assertEq(
    //         Token(newTokenAddress).totalSupply(),
    //         tokenGenerator.getInitialSupply()
    //     );
    //     assertEq(
    //         Token(newTokenAddress).getTokenCreator(),
    //         tokenGenerator.getTokenCreatorAddress(newTokenAddress)
    //     );

    //     // Check second token
    //     address newTokenAddress2 = tokenGenerator.getTokenAddress(1);
    //     assertEq(Token(newTokenAddress2).name(), TOKEN_NAME2);
    //     assertEq(Token(newTokenAddress2).symbol(), TOKEN_SYMBOL2);
    //     assertEq(
    //         Token(newTokenAddress2).totalSupply(),
    //         tokenGenerator.getInitialSupply()
    //     );
    //     assertEq(
    //         Token(newTokenAddress2).getTokenCreator(),
    //         tokenGenerator.getTokenCreatorAddress(newTokenAddress2)
    //     );

    //     // Check third token
    //     address newTokenAddress3 = tokenGenerator.getTokenAddress(2);
    //     assertEq(Token(newTokenAddress3).name(), TOKEN_NAME3);
    //     assertEq(Token(newTokenAddress3).symbol(), TOKEN_SYMBOL3);
    //     assertEq(
    //         Token(newTokenAddress3).totalSupply(),
    //         tokenGenerator.getInitialSupply()
    //     );
    //     assertEq(
    //         Token(newTokenAddress3).getTokenCreator(),
    //         tokenGenerator.getTokenCreatorAddress(newTokenAddress3)
    //     );

    //     // Check fourth token
    //     address newTokenAddress4 = tokenGenerator.getTokenAddress(3);
    //     assertEq(Token(newTokenAddress4).name(), TOKEN_NAME4);
    //     assertEq(Token(newTokenAddress4).symbol(), TOKEN_SYMBOL4);
    //     assertEq(
    //         Token(newTokenAddress4).totalSupply(),
    //         tokenGenerator.getInitialSupply()
    //     );
    //     assertEq(
    //         Token(newTokenAddress4).getTokenCreator(),
    //         tokenGenerator.getTokenCreatorAddress(newTokenAddress4)
    //     );
    // }

    function testShouldCreateAnewTokenContractMultipleTokens() public {
        // Define arrays to hold test data
        address[4] memory owners = [
            TOKEN_OWNER,
            TOKEN_OWNER2,
            TOKEN_OWNER2,
            TOKEN_OWNER3
        ];
        string[4] memory names = [
            TOKEN_NAME,
            TOKEN_NAME2,
            TOKEN_NAME3,
            TOKEN_NAME4
        ];
        string[4] memory symbols = [
            TOKEN_SYMBOL,
            TOKEN_SYMBOL2,
            TOKEN_SYMBOL3,
            TOKEN_SYMBOL4
        ];

        // Create all tokens
        for (uint i = 0; i < 4; i++) {
            vm.prank(owners[i]);
            tokenGenerator.createToken{value: fee}(names[i], symbols[i]);
        }

        // Verify all tokens
        for (uint i = 0; i < 4; i++) {
            address newTokenAddress = tokenGenerator.getTokenAddress(i);
            Token token = Token(newTokenAddress);

            // Verify token properties
            assertEq(token.name(), names[i]);
            assertEq(token.symbol(), symbols[i]);
            assertEq(token.totalSupply(), tokenGenerator.getInitialSupply());
            assertEq(
                token.getTokenCreator(),
                tokenGenerator.getTokenCreatorAddress(newTokenAddress)
            );
        }
    }

    function testShouldUpdateTokenDataCorrectlySingleToken() public {
        vm.prank(TOKEN_OWNER);
        address newTokenAddress = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL
        );

        assertEq(newTokenAddress, tokenGenerator.getTokenAddress(0));
        assertEq(
            TOKEN_OWNER,
            tokenGenerator.getTokenCreatorAddress(newTokenAddress)
        );
        assertEq(
            tokenGenerator.getCurrentSupplyWithoutInitialSupply(
                newTokenAddress
            ),
            0
        );
        assertEq(tokenGenerator.getTokenStage(newTokenAddress), 0);
    }

    function testShouldUpdateTokenDataCorrectlyMultipleTokens() public {
        // Define test data arrays
        address[3] memory owners = [TOKEN_OWNER, TOKEN_OWNER2, TOKEN_OWNER3];
        string[3] memory names = [TOKEN_NAME, TOKEN_NAME2, TOKEN_NAME3];
        string[3] memory symbols = [TOKEN_SYMBOL, TOKEN_SYMBOL2, TOKEN_SYMBOL3];
        address[] memory tokenAddresses = new address[](3);

        // Create multiple tokens and store their addresses
        for (uint i = 0; i < 3; i++) {
            vm.prank(owners[i]);
            tokenAddresses[i] = tokenGenerator.createToken{value: fee}(
                names[i],
                symbols[i]
            );

            // Verify token data immediately after creation
            assertEq(tokenAddresses[i], tokenGenerator.getTokenAddress(i));
            assertEq(
                owners[i],
                tokenGenerator.getTokenCreatorAddress(tokenAddresses[i])
            );
            assertEq(
                tokenGenerator.getCurrentSupplyWithoutInitialSupply(
                    tokenAddresses[i]
                ),
                0
            );
            assertEq(tokenGenerator.getTokenStage(tokenAddresses[i]), 0);
        }

        // Additional cross-check to ensure token registry is consistent
        for (uint i = 0; i < 3; i++) {
            address storedAddress = tokenGenerator.getTokenAddress(i);
            assertEq(storedAddress, tokenAddresses[i]);

            // Verify token contract values match expected values
            Token token = Token(storedAddress);
            assertEq(token.name(), names[i]);
            assertEq(token.symbol(), symbols[i]);
            assertEq(token.getTokenCreator(), owners[i]);
        }
    }

    function testShouldEmitEventAfterCreatingToken() public {
        vm.prank(TOKEN_OWNER);
        vm.expectEmit(true, true, true, false);
        emit TokenCreated(
            address(0xa16E02E87b7454126E5E10d957A927A7F5B5d2be),
            INITIAL_TOKEN_SUPPLY,
            TOKEN_OWNER
        );
        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);
    }

    ////////////////////
    // buyToken TESTs //
    ////////////////////
    function testShouldRevertIfICOIsActive() public {
        createToken();

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(
            tokenAddress,
            TOKEN_AMOUNT_THREE
        );
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(
            tokenAddress,
            TOKEN_AMOUNT_THREE
        );
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_TWO);
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_ONE);
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 2 ether}(tokenAddress, TOKEN_AMOUNT_ONE);
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 3 ether}(tokenAddress, TOKEN_AMOUNT_ONE);
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 4 ether}(tokenAddress, TOKEN_AMOUNT_ONE);
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 10 ether}(
            tokenAddress,
            TOKEN_AMOUNT_TWO
        );

        assertEq(
            tokenGenerator.getCurrentSupplyWithoutInitialSupply(tokenAddress),
            (tokenGenerator.getMaxSupply() - tokenGenerator.getInitialSupply())
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__TokenICOReached.selector
            )
        );
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, 1);
    }

    function testShouldReverIfDeadlineIsReached() public {
        createToken();

        vm.warp(block.timestamp + (DEADLINE_IN_DAYS * ONE_DAY_IN_SECONDS) + 1);
        vm.roll(block.number + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ICODeadlineReached.selector
            )
        );
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_ONE);
    }

    function testFuzz_ShouldNotRevertIfDeadlineIsNotReached(
        uint256 _amount
    ) public {
        uint256 amount = bound(_amount, 1, DEADLINE_IN_DAYS * 86400);

        createToken();

        vm.warp(block.timestamp + amount);
        vm.roll(block.number + 1);

        assertLe(
            tokenGenerator.getTokenDeadlineTimeLeft(tokenAddress),
            DEADLINE_IN_DAYS * 86400
        );
    }

    function testShouldRevertIfTokenAddressIsNotValid() public {
        createToken();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__WrongTokenAddress.selector
            )
        );
        tokenGenerator.buyToken{value: 1 ether}(BUYER, TOKEN_AMOUNT_ONE);
    }

    function testShouldRevertIfTokenAmountIsLessThanOne() public {
        createToken();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__TokenAmountTooLow.selector
            )
        );
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, 0);
    }

    function testShouldRevertIfAmountBoughtExceedsAvailableStageSupply()
        public
    {
        createToken();

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(
            tokenAddress,
            TOKEN_AMOUNT_THREE
        );
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(
            tokenAddress,
            TOKEN_AMOUNT_ONE + TOKEN_AMOUNT_TWO
        );

        uint256 availableStageSupply = tokenGenerator.getAvailableStageSupply(
            tokenAddress
        );
        uint256 currentStageSupply = tokenGenerator.getTokenCurrentStageSupply(
            tokenAddress
        );
        uint256 currentSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        assertEq(availableStageSupply, currentStageSupply - currentSupply);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator
                    .TokenGenerator__TokenAmountExceedsStageSellLimit
                    .selector,
                availableStageSupply
            )
        );
        tokenGenerator.buyToken{value: 1 ether}(
            tokenAddress,
            availableStageSupply + 1
        );
    }

    // function testFuzz_ShouldRevertIfETHValueSentIsLow(uint256 _amount) public {
    //     createToken();

    //     uint256 priceForTokens = tokenGenerator.calculatePriceForTokens(
    //         tokenAddress,
    //         TOKEN_AMOUNT_ONE
    //     );

    //     uint256 amount = bound(_amount, 1, priceForTokens - 1);

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             TokenGenerator.TokenGenerator__ValueSentIsLow.selector,
    //             priceForTokens
    //         )
    //     );
    //     tokenGenerator.buyToken{value: amount}(tokenAddress, TOKEN_AMOUNT_ONE);
    // }

    function testShouldUpdateParametersIfNextStageIsHitWithSingleBuy() public {
        createToken();

        uint256 startingTokenStage = tokenGenerator.getTokenStage(tokenAddress);
        assertEq(startingTokenStage, 0);

        uint256 currentStageSupply = tokenGenerator.getTokenCurrentStageSupply(
            tokenAddress
        );
        uint256 startingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(
            tokenAddress,
            TOKEN_AMOUNT_THREE
        );

        uint256 endingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);
        assertEq(endingTokenSupply, currentStageSupply);
        assertEq(endingTokenSupply, startingTokenSupply + TOKEN_AMOUNT_THREE);

        uint256 endingTokenStage = tokenGenerator.getTokenStage(tokenAddress);
        assertEq(endingTokenStage, startingTokenStage + 1);

        uint256 buyerTokenAmountBought = tokenGenerator
            .getBuyerTokenAmountBought(tokenAddress, BUYER);
        assertEq(buyerTokenAmountBought, TOKEN_AMOUNT_THREE);

        uint256 buyerEthAmountSpent = tokenGenerator.getBuyerEthAmountSpent(
            tokenAddress,
            BUYER
        );
        assertEq(buyerEthAmountSpent, 1 ether);
    }

    function testShouldUpdateParametersIfNextStageIsHitWithMultipleBuys()
        public
    {
        createToken();

        uint256 startingTokenStage = tokenGenerator.getTokenStage(tokenAddress);
        assertEq(startingTokenStage, 0);

        uint256 startingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        // buy #1
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(
            tokenAddress,
            TOKEN_AMOUNT_THREE
        );

        uint256 currentStageSupply = tokenGenerator.getTokenCurrentStageSupply(
            tokenAddress
        );

        // buy #2
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_TWO);

        // buy #3
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_TWO);

        uint256 endingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);
        assertEq(endingTokenSupply, currentStageSupply);
        assertEq(
            endingTokenSupply,
            startingTokenSupply +
                TOKEN_AMOUNT_THREE +
                TOKEN_AMOUNT_TWO +
                TOKEN_AMOUNT_TWO
        );

        uint256 endingTokenStage = tokenGenerator.getTokenStage(tokenAddress);
        assertEq(endingTokenStage, startingTokenStage + 2);

        uint256 buyerTokenAmountBought = tokenGenerator
            .getBuyerTokenAmountBought(tokenAddress, BUYER);
        assertEq(
            buyerTokenAmountBought,
            TOKEN_AMOUNT_THREE + TOKEN_AMOUNT_TWO + TOKEN_AMOUNT_TWO
        );

        uint256 buyerEthAmountSpent = tokenGenerator.getBuyerEthAmountSpent(
            tokenAddress,
            BUYER
        );
        assertEq(buyerEthAmountSpent, 3 ether);
    }

    function testShouldUpdateParametersIfNextStageIsNotHitWithSingleBuy()
        public
    {
        createToken();

        uint256 startingTokenStage = tokenGenerator.getTokenStage(tokenAddress);
        assertEq(startingTokenStage, 0);

        uint256 startingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_TWO);

        uint256 endingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);
        assertEq(endingTokenSupply, startingTokenSupply + TOKEN_AMOUNT_TWO);

        uint256 endingTokenStage = tokenGenerator.getTokenStage(tokenAddress);
        assertEq(endingTokenStage, startingTokenStage);

        uint256 buyerTokenAmountBought = tokenGenerator
            .getBuyerTokenAmountBought(tokenAddress, BUYER);
        assertEq(buyerTokenAmountBought, TOKEN_AMOUNT_TWO);

        uint256 buyerEthAmountSpent = tokenGenerator.getBuyerEthAmountSpent(
            tokenAddress,
            BUYER
        );
        assertEq(buyerEthAmountSpent, 1 ether);
    }

    function testShouldUpdateParametersIfNextStageIsNotHitWithMultipleBuys()
        public
    {
        createToken();

        uint256 startingTokenStage = tokenGenerator.getTokenStage(tokenAddress);
        assertEq(startingTokenStage, 0);

        uint256 startingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        // buy #1
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_ONE);

        // buy #2
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_ONE);

        // buy #3
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_ONE);

        uint256 endingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        assertEq(
            endingTokenSupply,
            startingTokenSupply +
                TOKEN_AMOUNT_ONE +
                TOKEN_AMOUNT_ONE +
                TOKEN_AMOUNT_ONE
        );

        uint256 endingTokenStage = tokenGenerator.getTokenStage(tokenAddress);
        assertEq(endingTokenStage, startingTokenStage);

        uint256 buyerTokenAmountBought = tokenGenerator
            .getBuyerTokenAmountBought(tokenAddress, BUYER);
        assertEq(
            buyerTokenAmountBought,
            TOKEN_AMOUNT_ONE + TOKEN_AMOUNT_ONE + TOKEN_AMOUNT_ONE
        );

        uint256 buyerEthAmountSpent = tokenGenerator.getBuyerEthAmountSpent(
            tokenAddress,
            BUYER
        );
        assertEq(buyerEthAmountSpent, 3 ether);
    }

    function testShoudMintTokensAndSendEthtWithSingleBuy() public {
        createToken();

        uint256 startingTokenBalance = Token(tokenAddress).balanceOf(
            tokenAddress
        );
        assertEq(startingTokenBalance, INITIAL_TOKEN_SUPPLY);

        uint256 startingEthBalance = tokenAddress.balance;
        assertEq(startingEthBalance, 0);

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_ONE);

        uint256 endingTokenBalance = Token(tokenAddress).balanceOf(
            tokenAddress
        );
        assertEq(endingTokenBalance, startingTokenBalance + TOKEN_AMOUNT_ONE);

        uint256 endingEthBalance = tokenAddress.balance;
        assertEq(endingEthBalance, 1 ether);
    }

    function testShoudMintTokensAndSendEthWithMultipleBuys() public {
        createToken();

        uint256 startingTokenBalance = Token(tokenAddress).balanceOf(
            tokenAddress
        );
        assertEq(startingTokenBalance, INITIAL_TOKEN_SUPPLY);

        uint256 startingEthBalance = tokenAddress.balance;
        assertEq(startingEthBalance, 0);

        // buy #1
        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_TWO);

        // buy #2
        vm.prank(BUYER2);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_TWO);

        // buy #3
        vm.prank(BUYER3);
        tokenGenerator.buyToken{value: 1 ether}(
            tokenAddress,
            TOKEN_AMOUNT_THREE
        );

        uint256 endingTokenBalance = Token(tokenAddress).balanceOf(
            tokenAddress
        );
        assertEq(
            endingTokenBalance,
            startingTokenBalance +
                TOKEN_AMOUNT_TWO +
                TOKEN_AMOUNT_TWO +
                TOKEN_AMOUNT_THREE
        );

        uint256 endingEthBalance = tokenAddress.balance;
        assertEq(endingEthBalance, 3 ether);
    }

    function testShoudMintTokensAndSendEthtWithSingleBuyMultipleTokens()
        public
    {
        // Define test data arrays
        address[3] memory owners = [TOKEN_OWNER, TOKEN_OWNER2, TOKEN_OWNER3];
        string[3] memory names = [TOKEN_NAME, TOKEN_NAME2, TOKEN_NAME3];
        string[3] memory symbols = [TOKEN_SYMBOL, TOKEN_SYMBOL2, TOKEN_SYMBOL3];
        uint256[3] memory tokenAmounts = [
            TOKEN_AMOUNT_ONE,
            TOKEN_AMOUNT_TWO,
            TOKEN_AMOUNT_THREE
        ];
        uint64[3] memory ethSpent = [0.5 ether, 1 ether, 1.5 ether];
        address[] memory tokenAddresses = new address[](3);

        for (uint i = 0; i < 3; i++) {
            // create tokens
            vm.prank(owners[i]);
            tokenAddresses[i] = tokenGenerator.createToken{value: fee}(
                names[i],
                symbols[i]
            );

            uint256 startingTokenBalance = Token(tokenAddresses[i]).balanceOf(
                tokenAddresses[i]
            );
            assertEq(startingTokenBalance, INITIAL_TOKEN_SUPPLY);

            uint256 startingEthBalance = tokenAddresses[i].balance;
            assertEq(startingEthBalance, 0);

            // buy tokens with the same buyer
            vm.prank(BUYER);
            tokenGenerator.buyToken{value: ethSpent[i]}(
                tokenAddresses[i],
                tokenAmounts[i]
            );

            uint256 endingTokenBalance = Token(tokenAddresses[i]).balanceOf(
                tokenAddresses[i]
            );
            assertEq(
                endingTokenBalance,
                startingTokenBalance + tokenAmounts[i]
            );

            uint256 endingEthBalance = tokenAddresses[i].balance;
            assertEq(endingEthBalance, ethSpent[i]);
        }
    }

    function testShoudUpdateBuyersDataWithMultipleTokensBuysOneBuyer() public {
        // Define test data arrays
        address[3] memory owners = [TOKEN_OWNER, TOKEN_OWNER2, TOKEN_OWNER3];
        uint256[3] memory tokenAmounts = [
            TOKEN_AMOUNT_ONE,
            TOKEN_AMOUNT_TWO,
            TOKEN_AMOUNT_THREE
        ];
        uint64[3] memory ethSpent = [0.5 ether, 1 ether, 1.5 ether];

        for (uint256 i = 0; i < owners.length; i++) {
            // create tokens
            vm.prank(owners[i]);
            tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);
            address newTokenAddress = tokenGenerator.getTokenAddress(i);

            // buy tokens
            vm.prank(BUYER);
            tokenGenerator.buyToken{value: ethSpent[i]}(
                newTokenAddress,
                tokenAmounts[i]
            );

            assertEq(
                tokenGenerator.getBuyerTokenAmountBought(
                    newTokenAddress,
                    BUYER
                ),
                tokenAmounts[i]
            );

            assertEq(
                tokenGenerator.getBuyerEthAmountSpent(newTokenAddress, BUYER),
                ethSpent[i]
            );
        }
    }

    function testShoudUpdateBuyersDataWithMultipleTokensBuysMultipleBuyers()
        public
    {
        // Define test data arrays
        address[3] memory owners = [TOKEN_OWNER, TOKEN_OWNER2, TOKEN_OWNER3];
        address[3] memory buyers = [BUYER, BUYER2, BUYER3];
        uint256[3] memory tokenAmounts = [
            TOKEN_AMOUNT_ONE,
            TOKEN_AMOUNT_TWO,
            TOKEN_AMOUNT_THREE
        ];
        uint64[3] memory ethSpent = [0.5 ether, 1 ether, 1.5 ether];

        for (uint256 i = 0; i < owners.length; i++) {
            // create tokens
            vm.prank(owners[i]);
            tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);
            address newTokenAddress = tokenGenerator.getTokenAddress(i);

            // buy tokens
            vm.prank(buyers[i]);
            tokenGenerator.buyToken{value: ethSpent[i]}(
                newTokenAddress,
                tokenAmounts[i]
            );

            assertEq(
                tokenGenerator.getBuyerTokenAmountBought(
                    newTokenAddress,
                    buyers[i]
                ),
                tokenAmounts[i]
            );

            assertEq(
                tokenGenerator.getBuyerEthAmountSpent(
                    newTokenAddress,
                    buyers[i]
                ),
                ethSpent[i]
            );
        }
    }

    function testShouldEmitEventAfterBuyingTokens() public {
        createToken();

        vm.prank(BUYER);
        vm.expectEmit(true, true, true, false);
        emit TokenBuy(tokenAddress, TOKEN_AMOUNT_ONE, BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, TOKEN_AMOUNT_ONE);
    }

    // function testShouldIncreasePriceAndSupplyForEveryStageAndShouldRaiseTheEthGoal()
    //     public
    // {
    //     createToken();

    //     uint256 stageSupply;
    //     uint256 stagePrice;
    //     uint256 stage;
    //     uint256 tokensPrice;
    //     uint256 currentSupply;

    //     for (uint256 i = 0; i < 8; i++) {
    //         currentSupply = tokenGenerator.getCurrentSupplyWithoutInitialSupply(
    //                 tokenAddress
    //             );
    //         stage = tokenGenerator.getTokenStage(tokenAddress);
    //         stageSupply = tokenGenerator.getTokenCurrentStageSupply(
    //             tokenAddress
    //         );
    //         stagePrice = tokenGenerator.getStagePrice(stage);
    //         tokensPrice = tokenGenerator.calculatePriceForTokens(
    //             tokenAddress,
    //             stageSupply - currentSupply
    //         );

    //         vm.prank(BUYER);
    //         tokenGenerator.buyToken{value: tokensPrice}(
    //             tokenAddress,
    //             stageSupply - currentSupply
    //         );

    //         // check if the price/supply is the same as in the array
    //         assertEq(tokenGenerator.getStageSupply(i), stageSupply);
    //         assertEq(tokenGenerator.getStagePrice(i), stagePrice);

    //         // check if the new price/supply is increasing with every stage
    //         if (i != 0) {
    //             uint256 previousTokenStageSupply = tokenGenerator
    //                 .getStageSupply(i - 1);
    //             uint256 previousTokenStagePrice = tokenGenerator.getStagePrice(
    //                 i - 1
    //             );

    //             assertLt(previousTokenStageSupply, stageSupply);
    //             assertLt(previousTokenStagePrice, stagePrice);
    //         }

    //         // check if the fund goal was met
    //         if (
    //             tokenGenerator.getCurrentSupplyWithoutInitialSupply(
    //                 tokenAddress
    //             ) == 800000
    //         ) {
    //             uint256 contractFinalBalance = tokenAddress.balance;

    //             assertEq(contractFinalBalance, tokenGenerator.getFundGoal());
    //         }
    //     }
    // }

    ///////////////////////////////////
    // calculatePriceForTokens TESTs //
    ///////////////////////////////////
    function testCalculateTokensPrice() public {
        createToken();

        uint256 newStage = tokenGenerator.checkNewStage(tokenAddress, 50000);

        uint256 tokensPrice = tokenGenerator.calculatePriceForTokens(
            tokenAddress,
            50000,
            newStage
        );

        console.log("Tokens price: ", tokensPrice);
    }

    /////////////////////////////////////
    // getTokenDeadlineTimeLeft  TESTs //
    /////////////////////////////////////
    function testFuzz_ShouldGetTimeLeftToICODeadline(uint256 _amount) public {
        uint256 amount = bound(_amount, 1, DEADLINE_IN_DAYS * 86400);

        createToken();

        vm.warp(block.timestamp + amount);
        vm.roll(block.number + 1);

        assertEq(tokenGenerator.getTokenDeadlineTimeLeft(tokenAddress), amount);
    }

    ////////////////////////////
    // getCurrentSupply TESTs //
    ////////////////////////////
    function testGetCurrentSupply() public {
        createToken();

        uint256 currentSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        console.log("Current supply: ", currentSupply);
    }

    /////////////////////////
    // getStagePrice TESTs //
    /////////////////////////
    function testGetStagePrice() public {
        createToken();

        uint256 tokenStage = tokenGenerator.getTokenStage(tokenAddress);

        uint256 stagePrice = tokenGenerator.getStagePrice(tokenStage);

        console.log("Stage price: ", stagePrice);
    }

    /////////////////////////
    // getTokenStage TESTs //
    /////////////////////////
    function testGetTokenStage() public {
        createToken();

        uint256 tokenStage = tokenGenerator.getTokenStage(tokenAddress);

        console.log("Token stage: ", tokenStage);
    }

    ///////////////////////////////////
    // getAvailableStageSupply TESTs //
    ///////////////////////////////////
    function testGetAvailableSupply() public {
        createToken();

        uint256 availableSupply = tokenGenerator.getAvailableStageSupply(
            tokenAddress
        );

        console.log("Available supply: ", availableSupply);
    }

    function testShouldCalculateNewStageWithPriorBuys() public {
        createToken();

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, 200000);

        uint256 tokensMinted = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);
        uint256 currentStage = tokenGenerator.getTokenStage(tokenAddress);
        console.log("Current stage: ", currentStage);
        console.log("Current supply: ", tokensMinted);

        uint256 tokenAmount = 107968;

        uint256 newStage = tokenGenerator.checkNewStage(
            tokenAddress,
            tokenAmount
        );

        console.log("New Stage: ", newStage);

        uint256 tokensPrice = tokenGenerator.calculatePriceForTokens(
            tokenAddress,
            tokenAmount,
            newStage
        );
        console.log(tokensPrice);
    }

    function testFuzz_ShouldAlwaysEndUpWithFundGoalAmountOfEth(
        uint256 _amount1
    ) public {
        createToken();

        uint256 amount1 = bound(_amount1, 1, 200000);
        uint256 amount2 = 800000 - amount1;

        uint256 newStage1 = tokenGenerator.checkNewStage(tokenAddress, amount1);

        uint256 gasStart = gasleft();
        uint256 tokensPrice1 = tokenGenerator.calculatePriceForTokens(
            tokenAddress,
            amount1,
            newStage1
        );
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // 8305
        // 23688
        console.log("Token1 amount: ", amount1);
        console.log("Token1 price: ", tokensPrice1);

        vm.prank(BUYER);
        tokenGenerator.buyToken{value: 1 ether}(tokenAddress, amount1);

        uint256 newStage2 = tokenGenerator.checkNewStage(tokenAddress, amount2);

        uint256 tokensPrice2 = tokenGenerator.calculatePriceForTokens(
            tokenAddress,
            amount2,
            newStage2
        );
        console.log("Token2 amount: ", amount2);
        console.log("Token2 price: ", tokensPrice2);

        assertEq(21 ether, tokensPrice1 + tokensPrice2);
    }

    function testGasCalculatePriceForTokens() public {
        createToken();

        uint256 tokenAount = 148987;

        uint256 newStage = tokenGenerator.checkNewStage(
            tokenAddress,
            tokenAount
        );

        uint256 gasStart = gasleft();
        tokenGenerator.calculatePriceForTokens2(
            tokenAddress,
            tokenAount,
            newStage
        );
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // 8462 gas - Using public view getStagePrice function
        // 8420 gas - Reading directly from the storage variable s_tokenStagePrice + using exact array boundries
        // withou exact array boundries gas = ~11400
        // 23803 gas - Using stagePrice memory array - its is because saving the 8 slot array = 16800 gas!
    }

    function testGasNewStage() public {
        createToken();

        uint256 gasStart = gasleft();
        tokenGenerator.checkNewStage(tokenAddress, 150000);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // 22780 gas - Using tokenStageSupply memory array
        // 7200 gas - Reading directly from s_tokenStageSupply
    }
}

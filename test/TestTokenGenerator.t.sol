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

    event TokenPurchase(
        address indexed tokenAddress,
        uint256 indexed tokenAmountPurchased,
        address indexed buyer,
        uint256 ethAmount
    );
    TokenGenerator public tokenGenerator;
    HelperConfig public helperConfig;

    uint256 public fee;
    uint256 deployerKey;
    uint256 icoDeadlineInDays;

    address tokenAddress;

    uint256 STARTING_INCREMENT = 0.0001 ether; // change if defined differently in the TokenGenerator contract
    uint256 INCREMENT_TWO = STARTING_INCREMENT * 2;
    uint256 INCREMENT_THREE = STARTING_INCREMENT * 3;

    uint256 ONE_DAY_IN_SECONDS = 86400;

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
    uint256 TOKEN_FUND_GOAL = 21 ether;
    uint256 INCORRECT_FUND_GOAL = 99 ether;

    uint256 TOKEN_AMOUNT_ONE = 50000;
    uint256 TOKEN_AMOUNT_TWO = 100000;
    uint256 TOKEN_AMOUNT_THREE = 200000;
    uint256 TOKEN_AMOUNT_FOUR = 225000;

    function setUp() external {
        DeployTokenGenerator deployTokenGenerator = new DeployTokenGenerator();
        (tokenGenerator, helperConfig) = deployTokenGenerator.run();
        (fee, deployerKey, icoDeadlineInDays) = helperConfig
            .activeNetworkConfig();

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

    function createTokenAndPurchaseOneBuyer() public {
        createToken();

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            TOKEN_AMOUNT_ONE,
            newStage
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );
    }

    function createTokenAndPurchaseMultipleBuyers() public {
        createToken();

        address[3] memory buyers = [BUYER, BUYER2, BUYER3];
        uint256[3] memory amounts = [
            TOKEN_AMOUNT_ONE,
            TOKEN_AMOUNT_TWO,
            TOKEN_AMOUNT_THREE
        ];

        for (uint i = 0; i < 3; i++) {
            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amounts[i]
            );
            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amounts[i],
                newStage
            );

            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amounts[i]
            );
        }
    }

    function createTokenAndPurchaseMaxPurchase() public {
        createToken();

        address[3] memory buyers = [BUYER, BUYER2, BUYER3];

        uint256 restAmount = 800000 - (TOKEN_AMOUNT_ONE + TOKEN_AMOUNT_TWO);

        uint256[3] memory amounts = [
            TOKEN_AMOUNT_ONE,
            TOKEN_AMOUNT_TWO,
            restAmount
        ];

        for (uint i = 0; i < 3; i++) {
            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amounts[i]
            );
            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amounts[i],
                newStage
            );

            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amounts[i]
            );
        }
    }

    function purchaseMaxSupplyOfTokens() public {
        address[3] memory buyers = [BUYER, BUYER2, BUYER3];

        uint256 restAmount = 800000 - (TOKEN_AMOUNT_ONE + TOKEN_AMOUNT_TWO);

        uint256[3] memory amounts = [
            TOKEN_AMOUNT_ONE,
            TOKEN_AMOUNT_TWO,
            restAmount
        ];

        for (uint i = 0; i < 3; i++) {
            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amounts[i]
            );
            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amounts[i],
                newStage
            );

            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amounts[i]
            );
        }
    }

    //////////////////////
    // constructor TEST //
    //////////////////////
    function testConstructorParametersShouldBeInitializedCorrectly()
        public
        view
    {
        assertEq(tokenGenerator.getCreationFees(), fee);
        assertEq(tokenGenerator.getIcoDeadlineInDays(), icoDeadlineInDays);
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
                TokenGenerator.TokenGenerator__InsufficientPayment.selector,
                fee
            )
        );
        tokenGenerator.createToken{value: amount}(TOKEN_NAME, TOKEN_SYMBOL);
    }

    function testShouldCreateNewTokenContractSingleToken() public {
        vm.prank(TOKEN_OWNER);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);

        address newTokenAddress = tokenGenerator.getTokenAddress(0);

        string memory tokenName = Token(newTokenAddress).name();
        string memory tokenSymbol = Token(newTokenAddress).symbol();
        uint256 tokenSupply = Token(newTokenAddress).totalSupply();
        address tokenCreator = Token(newTokenAddress).getTokenCreator();
        uint256 balanceOfTokenGenerator = Token(newTokenAddress).balanceOf(
            address(tokenGenerator)
        );
        uint256 balanceOfTokenContract = Token(newTokenAddress).balanceOf(
            address(newTokenAddress)
        );

        assertEq(tokenName, TOKEN_NAME);
        assertEq(tokenSymbol, TOKEN_SYMBOL);
        assertEq(tokenSupply, tokenGenerator.getInitialSupply());
        assertEq(tokenCreator, tokenGenerator.getTokenCreator(newTokenAddress));
        assertEq(balanceOfTokenGenerator, tokenGenerator.getInitialSupply());
        assertEq(balanceOfTokenContract, 0);
    }

    function testShouldCreateNewTokensContractsMultipleTokens() public {
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

            assertEq(token.name(), names[i]);
            assertEq(token.symbol(), symbols[i]);
            assertEq(token.totalSupply(), tokenGenerator.getInitialSupply());
            assertEq(
                token.getTokenCreator(),
                tokenGenerator.getTokenCreator(newTokenAddress)
            );
            assertEq(
                token.balanceOf(address(tokenGenerator)),
                tokenGenerator.getInitialSupply()
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
        assertEq(TOKEN_OWNER, tokenGenerator.getTokenCreator(newTokenAddress));
        assertEq(
            tokenGenerator.getCurrentSupplyWithoutInitialSupply(
                newTokenAddress
            ),
            0
        );
        assertEq(tokenGenerator.getCurrentPricingStage(newTokenAddress), 0);
        assertEq(
            tokenGenerator.getTokenCreationTimestamp(newTokenAddress),
            block.timestamp
        );
        assertEq(tokenGenerator.getTokenICOStatus(newTokenAddress), false);
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
                tokenGenerator.getTokenCreator(tokenAddresses[i])
            );
            assertEq(
                tokenGenerator.getCurrentSupplyWithoutInitialSupply(
                    tokenAddresses[i]
                ),
                0
            );
            assertEq(
                tokenGenerator.getCurrentPricingStage(tokenAddresses[i]),
                0
            );
            assertEq(
                tokenGenerator.getTokenCreationTimestamp(tokenAddresses[i]),
                block.timestamp
            );
            assertEq(
                tokenGenerator.getTokenICOStatus(tokenAddresses[i]),
                false
            );
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

    function testShouldUpdateTheAccumulatedFeesAndContractBalance() public {
        // Define test data arrays
        address[3] memory owners = [TOKEN_OWNER, TOKEN_OWNER2, TOKEN_OWNER3];
        string[3] memory names = [TOKEN_NAME, TOKEN_NAME2, TOKEN_NAME3];
        string[3] memory symbols = [TOKEN_SYMBOL, TOKEN_SYMBOL2, TOKEN_SYMBOL3];
        address[] memory tokenAddresses = new address[](3);

        uint256 accumulatedFees;

        for (uint i = 0; i < 3; i++) {
            uint256 startingEthBalance = address(tokenGenerator).balance;

            vm.prank(owners[i]);
            tokenAddresses[i] = tokenGenerator.createToken{value: fee}(
                names[i],
                symbols[i]
            );
            accumulatedFees += fee;
            uint256 endingEthBalance = address(tokenGenerator).balance;
            assertEq(endingEthBalance, startingEthBalance + fee);
        }
        assertEq(tokenGenerator.getAccumulatedFees(), accumulatedFees);
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

    /////////////////////////
    // purchaseToken TESTs //
    /////////////////////////
    function testFuzz_ShouldRevertIfPurchaseAmountExceedsMaxSupply(
        uint256 _amount
    ) public {
        uint256 amount = bound(_amount, 800001, type(uint256).max);

        createToken();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ExceedsMaxSupply.selector
            )
        );
        tokenGenerator.purchaseToken{value: 10 ether}(tokenAddress, amount);
    }

    function testFuzz_ShouldRevertIfMaxSupplyIsReachedSinglePurchase(
        uint256 _amount
    ) public {
        uint256 amount = bound(_amount, 1, 800000);

        createToken();

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: TOKEN_FUND_GOAL}(
            tokenAddress,
            800000
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ExceedsMaxSupply.selector
            )
        );
        tokenGenerator.purchaseToken{value: 10 ether}(tokenAddress, amount);
    }

    function testFuzz_ShouldRevertIfMaxSupplyIsReachedMultiplePurchases(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount4
    ) public {
        uint256 amount1 = bound(_amount1, 1, 220005);
        uint256 amount2 = bound(_amount2, 1, 350003);
        uint256 amount3 = 800000 - (amount1 + amount2);
        uint256 amount4 = bound(_amount4, 1, 800000);

        createToken();

        address[3] memory buyers = [BUYER, BUYER2, BUYER3];
        uint256[3] memory amounts = [amount1, amount2, amount3];

        for (uint i = 0; i < 3; i++) {
            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amounts[i]
            );
            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amounts[i],
                newStage
            );

            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amounts[i]
            );
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ExceedsMaxSupply.selector
            )
        );
        tokenGenerator.purchaseToken{value: 10 ether}(tokenAddress, amount4);
    }

    function testShouldRevertIfProvidedAddressIsZeroAddress() public {
        createToken();

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            TOKEN_AMOUNT_ONE,
            newStage
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ZeroAddressNotAllowed.selector
            )
        );
        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(
            address(0),
            TOKEN_AMOUNT_ONE
        );
    }

    // this get caught with different check (ExceedsMaxSupply)
    // function testShouldRevertIfICOIsActive() public {
    //     createTokenAndPurchaseMaxPurchase();

    //     assertEq(
    //         tokenGenerator.getCurrentSupplyWithoutInitialSupply(tokenAddress),
    //         (tokenGenerator.getMaxSupply() - tokenGenerator.getInitialSupply())
    //     );

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             TokenGenerator.TokenGenerator__TokenICOActive.selector
    //         )
    //     );
    //     tokenGenerator.purchaseToken{value: 1 ether}(tokenAddress, 1);
    // }

    function testShouldRevertIfTokenAddressIsNotValid() public {
        createToken();

        address[4] memory addresses = [BUYER, BUYER2, BUYER3, BUYER4];

        for (uint256 i; i < addresses.length; i++) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    TokenGenerator.TokenGenerator__InvalidTokenAddress.selector
                )
            );
            tokenGenerator.purchaseToken{value: 1 ether}(
                addresses[i],
                TOKEN_AMOUNT_ONE
            );
        }
    }

    function testShouldRevertIfTokenAmountIsZero() public {
        createToken();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__InvalidTokenAmount.selector
            )
        );
        tokenGenerator.purchaseToken{value: 1 ether}(tokenAddress, 0);
    }

    function testShouldReverIfDeadlineExpired() public {
        createToken();

        vm.warp(block.timestamp + (icoDeadlineInDays * ONE_DAY_IN_SECONDS) + 1);
        vm.roll(block.number + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ICODeadlineExpired.selector
            )
        );
        tokenGenerator.purchaseToken{value: 1 ether}(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );
    }

    function testFuzz_ShouldNotRevertIfDeadlineIsNotReached(
        uint256 _amount
    ) public {
        uint256 amount = bound(_amount, 1, icoDeadlineInDays * 86400);

        createToken();

        vm.warp(block.timestamp + amount);
        vm.roll(block.number + 1);
        // (`a` is less than `b`)
        assertLe(
            tokenGenerator.getElapsedTimeSinceCreation(tokenAddress),
            icoDeadlineInDays * 86400
        );
    }

    function testFuzz_ShouldRevertIfETHValueSentIsLow(uint256 _amount) public {
        createToken();

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );

        uint256 totalCost = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            TOKEN_AMOUNT_ONE,
            newStage
        );

        uint256 amount = bound(_amount, 1, totalCost - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__InsufficientPayment.selector,
                totalCost
            )
        );
        tokenGenerator.purchaseToken{value: amount}(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );
    }

    function testShouldUpdateTokenAndBuyerDataAfterSinglPurchase() public {
        createToken();

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            TOKEN_AMOUNT_FOUR
        );

        uint256 totalCost = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            TOKEN_AMOUNT_FOUR,
            newStage
        );

        uint256 startingTokenStage = tokenGenerator.getCurrentPricingStage(
            tokenAddress
        );
        // check if starting stage is 0
        assertEq(startingTokenStage, 0);

        uint256 startingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);
        // check the token balance of TokenGenerator contract is only the initial supply
        assertEq(
            Token(tokenAddress).balanceOf(address(tokenGenerator)),
            tokenGenerator.getInitialSupply()
        );

        uint256 startingEthBalance = address(tokenGenerator).balance;

        // purchase
        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalCost}(
            tokenAddress,
            TOKEN_AMOUNT_FOUR
        );

        uint256 endingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);
        // check if the balance of TokenGenerator contract is updated
        assertEq(endingTokenSupply, startingTokenSupply + TOKEN_AMOUNT_FOUR);
        assertEq(
            Token(tokenAddress).balanceOf(address(tokenGenerator)),
            tokenGenerator.getInitialSupply() +
                startingTokenSupply +
                TOKEN_AMOUNT_FOUR
        );

        uint256 endingEthBalance = address(tokenGenerator).balance;
        // check if the ETH balance updated
        assertEq(endingEthBalance, startingEthBalance + totalCost);

        uint256 endingTokenStage = tokenGenerator.getCurrentPricingStage(
            tokenAddress
        );
        // check if the stage is updated to newStage
        assertEq(endingTokenStage, newStage);

        uint256 buyerTokenAmountPurchased = tokenGenerator
            .getBuyerTokenAmountPurchased(tokenAddress, BUYER);
        // check if the buyers token amount is updated
        assertEq(buyerTokenAmountPurchased, TOKEN_AMOUNT_FOUR);

        uint256 buyerEthAmountSpent = tokenGenerator.getBuyerEthAmountSpent(
            tokenAddress,
            BUYER
        );
        // check if the buyers eth amount spent is updated
        assertEq(buyerEthAmountSpent, totalCost);
    }

    function testShouldUpdateokenAndBuyerDataAfterMultiplePurchases(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3
    ) public {
        uint256 amount1 = bound(_amount1, 1, 120005);
        uint256 amount2 = bound(_amount2, 1, 220003);
        uint256 amount3 = bound(_amount3, 1, 434003);

        createToken();

        address[3] memory buyers = [BUYER, BUYER2, BUYER3];
        uint256[3] memory amounts = [amount1, amount2, amount3];

        for (uint256 i; i < buyers.length; i++) {
            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amounts[i]
            );

            uint256 totalCost = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amounts[i],
                newStage
            );

            uint256 startingTokenSupply = tokenGenerator
                .getCurrentSupplyWithoutInitialSupply(tokenAddress);

            uint256 startingEthBalance = address(tokenGenerator).balance;

            // purchase
            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalCost}(
                tokenAddress,
                amounts[i]
            );

            uint256 endingTokenSupply = tokenGenerator
                .getCurrentSupplyWithoutInitialSupply(tokenAddress);
            // check if the balance of TokenGenerator contract is updated
            assertEq(endingTokenSupply, startingTokenSupply + amounts[i]);
            assertEq(
                Token(tokenAddress).balanceOf(address(tokenGenerator)),
                tokenGenerator.getInitialSupply() +
                    startingTokenSupply +
                    amounts[i]
            );

            uint256 endingEthBalance = address(tokenGenerator).balance;
            // check if the ETH balance updated
            assertEq(endingEthBalance, startingEthBalance + totalCost);

            uint256 endingTokenStage = tokenGenerator.getCurrentPricingStage(
                tokenAddress
            );
            // check if the stage is updated to newStage
            assertEq(endingTokenStage, newStage);

            uint256 buyerTokenAmountPurchased = tokenGenerator
                .getBuyerTokenAmountPurchased(tokenAddress, buyers[i]);
            // check if the buyers token amount is updated
            assertEq(buyerTokenAmountPurchased, amounts[i]);

            uint256 buyerEthAmountSpent = tokenGenerator.getBuyerEthAmountSpent(
                tokenAddress,
                buyers[i]
            );
            // check if the buyers eth amount spent is updated
            assertEq(buyerEthAmountSpent, totalCost);
        }
    }

    function testShouldChangeTheICOActiveStatusToTrueAfterMaxSupplyReached()
        public
    {
        createToken();

        assertEq(tokenGenerator.getTokenICOStatus(tokenAddress), false);

        purchaseMaxSupplyOfTokens();

        assertEq(tokenGenerator.getTokenICOStatus(tokenAddress), true);
    }

    function testShouldMintTokensAndSendEthToTokenGeneratorContractSinglePurchase()
        public
    {
        createToken();

        assertEq(address(tokenGenerator).balance, fee);
        assertEq(
            Token(tokenAddress).balanceOf(address(tokenGenerator)),
            INITIAL_TOKEN_SUPPLY
        );

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            TOKEN_AMOUNT_ONE,
            newStage
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );

        assertEq(address(tokenGenerator).balance, fee + totalPrice);
        assertEq(
            Token(tokenAddress).balanceOf(address(tokenGenerator)),
            INITIAL_TOKEN_SUPPLY + TOKEN_AMOUNT_ONE
        );
    }

    function testShouldMintTokensAndSendEthToTokenGeneratorContractMultiplePurchases()
        public
    {
        createToken();

        address[3] memory buyers = [BUYER, BUYER2, BUYER3];

        uint256 restAmount = 800000 - (TOKEN_AMOUNT_ONE + TOKEN_AMOUNT_TWO);

        uint256[3] memory amounts = [
            TOKEN_AMOUNT_ONE,
            TOKEN_AMOUNT_TWO,
            restAmount
        ];

        for (uint i = 0; i < 3; i++) {
            uint256 startingEthBalance = address(tokenGenerator).balance;
            uint256 startingTokenBalance = Token(tokenAddress).balanceOf(
                address(tokenGenerator)
            );

            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amounts[i]
            );
            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amounts[i],
                newStage
            );

            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amounts[i]
            );

            uint256 endingEthBalance = address(tokenGenerator).balance;
            uint256 endingTokenBalance = Token(tokenAddress).balanceOf(
                address(tokenGenerator)
            );

            assertEq(endingEthBalance, startingEthBalance + totalPrice);
            assertEq(endingTokenBalance, startingTokenBalance + amounts[i]);

            assertEq(address(tokenAddress).balance, 0);
            assertEq(Token(tokenAddress).balanceOf(tokenAddress), 0);
        }
    }

    function testShouldEmitEventAfterPurchasingTokens() public {
        createToken();

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            TOKEN_AMOUNT_ONE,
            newStage
        );

        vm.prank(BUYER);
        vm.expectEmit(true, true, true, false);
        emit TokenPurchase(tokenAddress, TOKEN_AMOUNT_ONE, BUYER, totalPrice);
        tokenGenerator.purchaseToken{value: totalPrice}(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );
    }

    ///////////////////////////////////
    // calculatePurchaseCost TESTs ////
    ///////////////////////////////////
    function testShouldRevertIfNewStageIsLesserThanCurrentStage() public {
        createToken();

        createTokenAndPurchaseMultipleBuyers();
        // `a` is greater than `b`
        assertGt(tokenGenerator.getCurrentPricingStage(tokenAddress), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__InvalidStageCalculation.selector
            )
        );
        tokenGenerator.calculatePurchaseCost(tokenAddress, TOKEN_AMOUNT_ONE, 0);
    }

    function testFuzz_ShouldRevertIfNewStageIsGreaterThanMaxStage(
        uint256 _amount
    ) public {
        uint256 amount = bound(_amount, 8, type(uint256).max);

        createToken();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__InvalidStageCalculation.selector
            )
        );
        tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            TOKEN_AMOUNT_ONE,
            amount
        );
    }

    function testShouldCalculateTotalPriceForTokensPerStage() public {
        createToken();

        uint24[8] memory stageSupply = [
            200000, //  Stage 0: 0    - 200k tokens (0.6  ETH total cost)
            400000, //  Stage 1: 200k - 400k tokens (0.9  ETH total cost)
            500000, //  Stage 2: 400k - 500k tokens (0.75 ETH total cost)
            550000, //  Stage 3: 500k - 550k tokens (1    ETH total cost)
            600000, //  Stage 4: 550k - 600k tokens (1.75 ETH total cost)
            650000, //  Stage 5: 600k - 650k tokens (2.75 ETH total cost)
            700000, //  Stage 6: 650k - 700k tokens (3.75 ETH total cost)
            800000 //   Stage 7: 700k - 800k tokens (9.5  ETH total cost)
        ];
        uint48[8] memory stagePrice = [
            3000000000000, //   0.000003  ETH per token
            4500000000000, //   0.0000045 ETH per token
            7500000000000, //   0.0000075 ETH per token
            20000000000000, //  0.00002   ETH per token
            35000000000000, //  0.000035  ETH per token
            55000000000000, //  0.000055  ETH per token
            75000000000000, //  0.000075  ETH per token
            95000000000000 //   0.000095  ETH per token
        ];

        uint256 totalPriceAccumulated;

        for (uint256 stage = 0; stage < 8; stage++) {
            uint256 currentTokenSupply = tokenGenerator
                .getCurrentSupplyWithoutInitialSupply(tokenAddress);
            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                stageSupply[stage] - currentTokenSupply
            );
            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                stageSupply[stage] - currentTokenSupply,
                newStage
            );

            vm.prank(BUYER);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                stageSupply[stage] - currentTokenSupply
            );

            totalPriceAccumulated += totalPrice;

            assertEq(
                totalPrice,
                (stageSupply[stage] - currentTokenSupply) * stagePrice[stage]
            );
        }
        assertEq(totalPriceAccumulated, TOKEN_FUND_GOAL);
    }

    function testShouldExactStagePriceForTokensPlusOne() public {
        createToken();

        uint256 amount = TOKEN_AMOUNT_THREE + 1;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            amount
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            amount,
            newStage
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(tokenAddress, amount);

        uint256 totalPriceForExactStage = tokenGenerator.getStagePrice(0) *
            TOKEN_AMOUNT_THREE;
        uint256 totalPriceForOneTokenNextStage = tokenGenerator.getStagePrice(
            1
        ) * 1;
        uint256 fullPrice = totalPriceForExactStage +
            totalPriceForOneTokenNextStage;

        assertEq(totalPrice, fullPrice);
    }

    function testShouldCalculatePriceForOnePurchaseSpanningMultipleStages()
        public
    {
        createToken();

        uint256 amount = 525000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            amount
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            amount,
            newStage
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(tokenAddress, amount);

        uint256 stagePrice1 = 200000 * 3000000000000;
        console.log("Stage price1:", stagePrice1);
        uint256 stagePrice2 = 200000 * 4500000000000;
        console.log("Stage price2:", stagePrice2);
        uint256 stagePrice3 = 100000 * 7500000000000;
        console.log("Stage price3:", stagePrice3);
        uint256 stagePrice4 = 25000 * 20000000000000;
        console.log("Stage price4:", stagePrice4);

        assertEq(
            totalPrice,
            stagePrice1 + stagePrice2 + stagePrice3 + stagePrice4
        );
    }

    function testShouldCalculateTotalPriceWithinTheSameStagePurchase() public {
        createToken();

        uint16[4] memory amounts = [35000, 44000, 62000, 5000];

        for (uint256 i = 0; i < 4; i++) {
            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amounts[i]
            );
            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amounts[i],
                newStage
            );

            vm.prank(BUYER);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amounts[i]
            );

            // calculating directly from array sometimes causes overflow/underflow error
            uint256 amount = amounts[i];
            assertEq(totalPrice, 3000000000000 * amount);
        }
    }

    function testShouldCalculatePriceForMaxPurchase() public {
        createToken();

        uint256 amount = 800000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            amount
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            amount,
            newStage
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(tokenAddress, amount);

        assertEq(totalPrice, TOKEN_FUND_GOAL);
    }

    function testShouldMaintainConsistencyAcrossMultipleCalls() public {
        createToken();

        uint256 tokenAmount = 123456;
        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

        // Call multiple times - should return same result
        uint256 cost1 = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            tokenAmount,
            newStage
        );
        uint256 cost2 = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            tokenAmount,
            newStage
        );
        uint256 cost3 = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            tokenAmount,
            newStage
        );

        assertEq(cost1, cost2);
        assertEq(cost2, cost3);
    }

    function testShouldEndUpWithFundGoalOfEthIfMaxSupplyReached(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3
    ) public {
        createToken();

        uint256 amount1 = bound(_amount1, 1, 350000);
        uint256 amount2 = bound(_amount2, 1, 140000);
        uint256 amount3 = bound(_amount3, 1, 280000);
        uint256 restAmount = 800000 - (amount1 + amount2 + amount3);

        address[4] memory buyers = [BUYER, BUYER2, BUYER3, BUYER4];

        uint256[4] memory amounts = [amount1, amount2, amount3, restAmount];

        uint256 totalPriceAccumulated;

        for (uint i = 0; i < 4; i++) {
            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amounts[i]
            );
            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amounts[i],
                newStage
            );

            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amounts[i]
            );

            totalPriceAccumulated += totalPrice;
        }

        assertEq(totalPriceAccumulated, TOKEN_FUND_GOAL);
    }

    function testGascalculatePurchaseCost() public {
        createToken();

        uint256 tokenAmount = 148987;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

        uint256 gasStart = gasleft();
        tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            tokenAmount,
            newStage
        );
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // 8462 gas - Using public view getStagePrice function
        // 8420 gas - Reading directly from the storage variable s_tokenStagePrice + using exact array boundries
        // without exact array boundries gas = ~11400
        // 23803 gas - Using stagePrice memory array - its is because saving the 8 slot array = 16800 gas!
    }

    /////////////////////////////
    // calculateNewStage TESTs //
    /////////////////////////////
    function testShouldCalculateExactNewStageForEveryStage() public {
        createToken();

        uint24[8] memory stageSupply = [
            200000, //  Stage 0: 0    - 200k tokens (0.6  ETH total cost)
            400000, //  Stage 1: 200k - 400k tokens (0.9  ETH total cost)
            500000, //  Stage 2: 400k - 500k tokens (0.75 ETH total cost)
            550000, //  Stage 3: 500k - 550k tokens (1    ETH total cost)
            600000, //  Stage 4: 550k - 600k tokens (1.75 ETH total cost)
            650000, //  Stage 5: 600k - 650k tokens (2.75 ETH total cost)
            700000, //  Stage 6: 650k - 700k tokens (3.75 ETH total cost)
            800000 //   Stage 7: 700k - 800k tokens (9.5  ETH total cost)
        ];

        for (uint256 i = 0; i < 8; i++) {
            uint256 amount = stageSupply[i];
            uint256 currentSupply = tokenGenerator
                .getCurrentSupplyWithoutInitialSupply(tokenAddress);

            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amount - currentSupply
            );
            if (amount == 800000) {
                assertEq(newStage, i);
            } else {
                assertEq(newStage, i + 1);
            }

            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amount - currentSupply,
                newStage
            );

            vm.prank(BUYER);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amount - currentSupply
            );
        }
    }

    function testShouldCalculateNewStageWithoutPriorPurchase() public {
        createToken();

        uint256 amount1 = 150000;
        uint256 expectedStage1 = 0;
        uint256 stage1 = tokenGenerator.calculateNewStage(
            tokenAddress,
            amount1
        );

        assertEq(stage1, expectedStage1);

        uint256 amount2 = 235666;
        uint256 expectedStage2 = 1;
        uint256 stage2 = tokenGenerator.calculateNewStage(
            tokenAddress,
            amount2
        );

        assertEq(stage2, expectedStage2);

        uint256 amount3 = 628000;
        uint256 expectedStage3 = 5;
        uint256 stage3 = tokenGenerator.calculateNewStage(
            tokenAddress,
            amount3
        );

        assertEq(stage3, expectedStage3);
    }

    function testShouldCalculateNewStageWithPriorPurchase() public {
        createToken();

        uint256 tokenAmount1 = 530000; // stage 3

        uint256 startingStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount1
        );

        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            tokenAmount1,
            startingStage
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(
            tokenAddress,
            tokenAmount1
        );

        uint256 currentStage = tokenGenerator.getCurrentPricingStage(
            tokenAddress
        );

        assertEq(currentStage, 3);

        console.log("Current stage: ", currentStage);

        uint256 tokenAmount2 = 10000;

        uint256 endingStage1 = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount2
        );

        console.log("New Stage: ", endingStage1);

        assertEq(endingStage1, 3);

        uint256 tokenAmount3 = 20000;

        uint256 endingStage2 = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount3
        );

        console.log("New Stage: ", endingStage2);

        assertEq(endingStage2, 4);
    }

    function testShouldCalculateMaxStageIfMaxSupplyIsPurchased() public {
        createToken();

        uint256 tokenAmount = 800000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

        assertEq(newStage, 7);

        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            tokenAmount,
            newStage
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(
            tokenAddress,
            tokenAmount
        );
    }

    function testFuzz_ShouldEndUpWithMaxStage(
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3
    ) public {
        createToken();

        uint256 amount1 = bound(_amount1, 200000, 205889);
        uint256 amount2 = bound(_amount2, 200000, 225445);
        uint256 amount3 = bound(_amount3, 200000, 214689);
        uint256 restAmount = 800000 - (amount1 + amount2 + amount3);

        uint256[4] memory amounts = [amount1, amount2, amount3, restAmount];

        uint256 newStage;
        uint256 previousStage;

        for (uint256 i = 0; i < 4; i++) {
            newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amounts[i]
            );

            assertLt(previousStage, newStage);

            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amounts[i],
                newStage
            );

            vm.prank(BUYER);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amounts[i]
            );

            previousStage = newStage;
        }
        assertEq(newStage, 7);
    }

    function testGasNewStage() public {
        createToken();

        uint256 gasStart = gasleft();
        tokenGenerator.calculateNewStage(tokenAddress, 150000);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // 22780 gas - Using tokenStageSupply memory array
        // 7200 gas - Reading directly from s_tokenStageSupply
    }

    /////////////////////////////////////
    // getTokenDeadlineTimeLeft  TESTs //
    /////////////////////////////////////
    function testFuzz_ShouldGetTimeLeftToICODeadline(uint256 _amount) public {
        uint256 amount = bound(_amount, 1, icoDeadlineInDays * 86400);

        createToken();

        vm.warp(block.timestamp + amount);
        vm.roll(block.number + 1);

        assertEq(
            tokenGenerator.getElapsedTimeSinceCreation(tokenAddress),
            amount
        );
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

        uint256 tokenStage = tokenGenerator.getCurrentPricingStage(
            tokenAddress
        );

        uint256 stagePrice = tokenGenerator.getStagePrice(tokenStage);

        console.log("Stage price: ", stagePrice);
    }

    /////////////////////////
    // getCurrentPricingStage TESTs //
    /////////////////////////
    function testgetCurrentPricingStage() public {
        createToken();

        uint256 tokenStage = tokenGenerator.getCurrentPricingStage(
            tokenAddress
        );

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

    // function testFuzz_ShouldAlwaysEndUpWithFundGoalAmountOfEth(
    //     uint256 _amount1,
    //     uint256 _amount2
    // ) public {
    //     createToken();

    //     uint256 amount1 = bound(_amount1, 1, 200000);
    //     uint256 amount2 = bound(_amount2, 1, 200000);
    //     uint256 amount3 = 800000 - (amount1 + amount2);

    //     // buy #1
    //     uint256 newStage1 = tokenGenerator.calculateNewStage(
    //         tokenAddress,
    //         amount1
    //     );

    //     uint256 tokensPrice1 = tokenGenerator.calculatePurchaseCost(
    //         tokenAddress,
    //         amount1,
    //         newStage1
    //     );

    //     console.log("Token1 amount: ", amount1);
    //     console.log("Token1 price: ", tokensPrice1);
    //     console.log("Token1 new stage: ", newStage1);

    //     uint256 gasStart1 = gasleft();
    //     vm.prank(BUYER);
    //     tokenGenerator.purchaseToken{value: tokensPrice1}(
    //         tokenAddress,
    //         amount1
    //     );
    //     uint256 gasUsed1 = gasStart1 - gasleft();
    //     console.log("Gas used #1:", gasUsed1);

    //     assertEq(
    //         newStage1,
    //         tokenGenerator.getCurrentPricingStage(tokenAddress)
    //     );

    //     // buy #2
    //     uint256 newStage2 = tokenGenerator.calculateNewStage(
    //         tokenAddress,
    //         amount2
    //     );

    //     uint256 tokensPrice2 = tokenGenerator.calculatePurchaseCost(
    //         tokenAddress,
    //         amount2,
    //         newStage2
    //     );

    //     console.log("Token2 amount: ", amount2);
    //     console.log("Token2 price: ", tokensPrice2);
    //     console.log("Token2 new stage: ", newStage2);

    //     uint256 gasStart2 = gasleft();
    //     vm.prank(BUYER);
    //     tokenGenerator.purchaseToken{value: tokensPrice2}(
    //         tokenAddress,
    //         amount2
    //     );
    //     uint256 gasUsed2 = gasStart2 - gasleft();
    //     console.log("Gas used #2:", gasUsed2);

    //     assertEq(
    //         newStage2,
    //         tokenGenerator.getCurrentPricingStage(tokenAddress)
    //     );

    //     // buy #3
    //     uint256 newStage3 = tokenGenerator.calculateNewStage(
    //         tokenAddress,
    //         amount3
    //     );

    //     uint256 tokensPrice3 = tokenGenerator.calculatePurchaseCost(
    //         tokenAddress,
    //         amount3,
    //         newStage3
    //     );
    //     console.log("Token3 amount: ", amount3);
    //     console.log("Token3 price: ", tokensPrice3);
    //     console.log("Token3 new stage: ", newStage3);

    //     uint256 gasStart3 = gasleft();
    //     vm.prank(BUYER);
    //     tokenGenerator.purchaseToken{value: tokensPrice3}(
    //         tokenAddress,
    //         amount3
    //     );
    //     uint256 gasUsed3 = gasStart3 - gasleft();
    //     console.log("Gas used #3:", gasUsed3);

    //     assertEq(21 ether, tokensPrice1 + tokensPrice2 + tokensPrice3);
    // }
}

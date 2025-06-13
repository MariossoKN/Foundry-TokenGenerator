// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

import {DeployTokenGenerator} from "../script/DeployTokenGenerator.s.sol";
import {TokenGenerator} from "../src/TokenGenerator.sol";
import {Token} from "../src/Token.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {Test, console, StdCheats} from "../../lib/forge-std/src/Test.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract TestTokenGenerator is StdCheats, Test {
    event TokenCreated(
        address indexed tokenAddress,
        uint256 indexed tokenSupply,
        address indexed tokenCreator
    );

    event TokenPurchase(
        address indexed tokenAddress,
        uint256 indexed tokenAmountPurchased,
        address indexed buyer,
        uint256 ethAmount,
        bool isICOActive
    );

    event BuyerFundsWithdrawn(
        address indexed tokenAddress,
        address indexed callerAddres,
        uint256 indexed ethAmountWithdrawed
    );

    event FeesWithdrawed(address owner, uint256 ethAmount);

    event OwnerAddressChanged(
        address indexed previousOwner,
        address indexed newOwner
    );

    event PoolCreatedliquidityAddedLPTokensBurned(
        address tokenAddress,
        address poolAddress,
        uint256 liqudityBurnt
    );

    event TokensClaimed(
        address tokenAddress,
        address buyerAddress,
        uint256 tokenAmountClaimed
    );

    TokenGenerator public tokenGenerator;
    HelperConfig public helperConfig;

    // IUniswapV2Factory public uniswapV2Factory;
    // IUniswapV2Router02 public uniswapV2Router;

    uint256 public fee;
    uint256 deployerKey;
    uint256 icoDeadlineInDays;

    address uniswapV2FactoryAddress;
    address uniswapV2RouterAddress;
    address weth;

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
    uint256 MAX_SUPPLY_WITHOUT_INIT_SUPPLY = 800000;
    uint256 TOKEN_FUND_GOAL = 21 ether;
    uint256 INCORRECT_FUND_GOAL = 99 ether;

    uint256 TOKEN_AMOUNT_ONE = 50000;
    uint256 TOKEN_AMOUNT_TWO = 100000;
    uint256 TOKEN_AMOUNT_THREE = 200000;
    uint256 TOKEN_AMOUNT_FOUR = 225000;

    function setUp() external {
        DeployTokenGenerator deployTokenGenerator = new DeployTokenGenerator();
        (tokenGenerator, helperConfig) = deployTokenGenerator.run();
        (
            fee,
            deployerKey,
            icoDeadlineInDays,
            uniswapV2FactoryAddress,
            uniswapV2RouterAddress
        ) = helperConfig.activeNetworkConfig();

        weth = IUniswapV2Router02(uniswapV2RouterAddress).WETH();

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

    function createTokenAndMaxPurchase() public {
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

    function isMainnetFork() internal view returns (bool) {
        return block.chainid == 1;
    }

    // *************************** TESTS *************************** //

    //////////////////////
    // constructor TEST //
    //////////////////////
    function testConstructorParametersShouldBeInitializedCorrectly()
        public
        view
    {
        assertEq(tokenGenerator.getCreationFee(), fee);
        assertEq(tokenGenerator.getIcoDeadlineInDays(), icoDeadlineInDays);
        assertEq(
            tokenGenerator.getUniswapV2FactoryAddress(),
            uniswapV2FactoryAddress
        );
        assertEq(
            tokenGenerator.getUniswapV2RouterAddress(),
            uniswapV2RouterAddress
        );
    }

    ///////////////////
    // receive TESTs //
    ///////////////////
    function testFuzz_ShouldRevertIfETHIsSentToContract(
        uint256 _amount
    ) public {
        uint256 amount = bound(_amount, 1, BUYER.balance);

        uint256 startingBalance = address(tokenGenerator).balance;

        vm.prank(BUYER);
        vm.expectRevert("ETH not accepted");
        (bool success, ) = address(tokenGenerator).call{value: amount}("");
        require(success, "Call failed");

        uint256 endingBalance = address(tokenGenerator).balance;

        assertEq(startingBalance, endingBalance);
    }

    ////////////////////
    // fallback TESTs //
    ////////////////////
    function testShouldRevertIfInvalidFunctionIsCalled() public {
        vm.expectRevert();
        (bool success, ) = address(tokenGenerator).call(
            abi.encodeWithSignature("nonExistentFunction()")
        );

        console.log(success);
    }

    function testShouldRevertIfInvalidFunctionIsCalledAndETHSent() public {
        uint256 startingBalance = address(tokenGenerator).balance;

        vm.expectRevert();
        (bool success, ) = address(tokenGenerator).call{value: 1 ether}(
            abi.encodeWithSignature("nonExistentFunction()")
        );

        console.log(success);

        uint256 endingBalance = address(tokenGenerator).balance;

        assertEq(startingBalance, endingBalance);
    }

    ///////////////////////
    // createToken TESTs //
    ///////////////////////
    function testFuzz_ShouldRevertIfValueSentIsLessThanFee(
        uint256 _amount
    ) public {
        // amount is always less then min. fee
        uint256 amount = bound(_amount, 0, fee - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__InsufficientPayment.selector,
                fee
            )
        );
        tokenGenerator.createToken{value: amount}(TOKEN_NAME, TOKEN_SYMBOL);
    }

    function testFuzz_ShouldNotRevertIfValueSentIsMoreThanFee(
        uint256 _amount
    ) public {
        // amount is always more then min. fee
        vm.prank(TOKEN_OWNER);
        uint256 amount = bound(_amount, fee, TOKEN_OWNER.balance);

        tokenGenerator.createToken{value: amount}(TOKEN_NAME, TOKEN_SYMBOL);
    }

    function testShouldCreateNewTokenContractSingleToken() public {
        // create new token
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

        // verify if data is correct
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
        assertEq(tokenGenerator.getTokenEthAmountFunded(tokenAddress), 0);
        assertEq(tokenGenerator.getTokenICOStatus(newTokenAddress), false);
        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), false);
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
                tokenGenerator.getTokenEthAmountFunded(tokenAddresses[i]),
                0
            );

            assertEq(
                tokenGenerator.getTokenICOStatus(tokenAddresses[i]),
                false
            );
            assertEq(
                tokenGenerator.getTokenFundingComplete(tokenAddresses[i]),
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
        if (isMainnetFork()) {
            console.log(
                "*** Test skipped on Fork (Owner address fallback error, works on Anvil) ***"
            );
            vm.skip(true);
        }

        vm.prank(TOKEN_OWNER);
        vm.expectEmit(true, true, true, false);
        emit TokenCreated(
            address(0xa16E02E87b7454126E5E10d957A927A7F5B5d2be),
            INITIAL_TOKEN_SUPPLY,
            TOKEN_OWNER
        );
        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);
    }

    function testShouldReturnCorrectTokenAddress() public {
        address[3] memory owners = [TOKEN_OWNER, TOKEN_OWNER2, TOKEN_OWNER3];
        string[3] memory names = [TOKEN_NAME, TOKEN_NAME2, TOKEN_NAME3];
        string[3] memory symbols = [TOKEN_SYMBOL, TOKEN_SYMBOL2, TOKEN_SYMBOL3];
        address[] memory tokenAddresses = new address[](3);

        for (uint i = 0; i < 3; i++) {
            vm.prank(owners[i]);
            tokenAddresses[i] = tokenGenerator.createToken{value: fee}(
                names[i],
                symbols[i]
            );
            assertEq(tokenAddresses[i], tokenGenerator.getTokenAddress(i));
        }
    }

    /////////////////////////
    // purchaseToken TESTs //
    /////////////////////////
    function testShouldRevertIfTokendAddressIsZeroAddress() public {
        // using helper function to create new token
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
        // buying amount3 hits the max supply

        // buying amount4 exceeds the max supply
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

    function testShouldRevertIfTokenAddressIsNotValid() public {
        createToken();

        // Buyers addresses
        address[4] memory invalidTokenAddresses = [
            BUYER,
            BUYER2,
            BUYER3,
            BUYER4
        ];

        for (uint256 i; i < invalidTokenAddresses.length; i++) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    TokenGenerator.TokenGenerator__InvalidTokenAddress.selector
                )
            );
            tokenGenerator.purchaseToken{value: 1 ether}(
                invalidTokenAddresses[i],
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

    function testFuzz_ShouldReverIfDeadlineExpired(uint256 _amount) public {
        uint256 amount = bound(_amount, 1, type(uint128).max);

        createToken();

        // increase the block.timestamp so the deadline expires
        vm.warp(
            block.timestamp + (icoDeadlineInDays * ONE_DAY_IN_SECONDS) + amount
        );
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
        // block.timestamp will always be less the the min. deadline
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

        // sent value will be always less than calculated value
        uint256 amount = bound(_amount, 1, totalCost - 1);

        vm.prank(BUYER);
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

    function testFuzz_ShouldRevertIfETHValueSentIsHigher(
        uint256 _amount
    ) public {
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

        // sent value will be always higher than calculated value
        uint256 amount = bound(_amount, totalCost + 1, BUYER.balance);

        vm.prank(BUYER);
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

        // check starting token data
        uint256 startingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        assertEq(tokenGenerator.getCurrentPricingStage(tokenAddress), 0);
        assertEq(startingTokenSupply, 0);
        assertEq(tokenGenerator.getTokenEthAmountFunded(tokenAddress), 0);

        assertEq(
            Token(tokenAddress).balanceOf(address(tokenGenerator)),
            INITIAL_TOKEN_SUPPLY
        );

        // check starting buyer data
        assertEq(
            tokenGenerator.getBuyerTokenAmountPurchased(tokenAddress, BUYER),
            0
        );
        assertEq(tokenGenerator.getBuyerEthAmountSpent(tokenAddress, BUYER), 0);

        uint256 startingEthBalance = address(tokenGenerator).balance;

        // purchase
        console.log("------------------- PURCHASE -------------------");
        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalCost}(
            tokenAddress,
            TOKEN_AMOUNT_FOUR
        );

        // check token ending data
        uint256 endingTokenSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        assertEq(tokenGenerator.getCurrentPricingStage(tokenAddress), newStage);
        assertEq(endingTokenSupply, startingTokenSupply + TOKEN_AMOUNT_FOUR);
        assertEq(
            tokenGenerator.getTokenEthAmountFunded(tokenAddress),
            totalCost
        );

        assertEq(
            Token(tokenAddress).balanceOf(address(tokenGenerator)),
            INITIAL_TOKEN_SUPPLY + TOKEN_AMOUNT_FOUR
        );

        // check buyer ending data
        uint256 endingEthBalance = address(tokenGenerator).balance;

        assertEq(
            tokenGenerator.getBuyerTokenAmountPurchased(tokenAddress, BUYER),
            TOKEN_AMOUNT_FOUR
        );
        assertEq(
            tokenGenerator.getBuyerEthAmountSpent(tokenAddress, BUYER),
            totalCost
        );

        assertEq(endingEthBalance, startingEthBalance + totalCost);
    }

    function testShouldUpdateTokenAndBuyerDataAfterMultiplePurchases() public {
        createToken();

        address[3] memory buyers = [BUYER, BUYER2, BUYER3];
        uint24[3] memory amounts = [120005, 220003, 434003];

        uint256 ethAmountFunded;

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
            console.log("------------------- PURCHASE -------------------");
            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalCost}(
                tokenAddress,
                amounts[i]
            );

            ethAmountFunded += totalCost;

            // check token data
            assertEq(
                tokenGenerator.getCurrentPricingStage(tokenAddress),
                newStage
            );
            uint256 endingTokenSupply = tokenGenerator
                .getCurrentSupplyWithoutInitialSupply(tokenAddress);
            assertEq(endingTokenSupply, startingTokenSupply + amounts[i]);
            assertEq(
                tokenGenerator.getTokenEthAmountFunded(tokenAddress),
                ethAmountFunded
            );

            // check if the balances of TokenGenerator contract are updated
            assertEq(
                Token(tokenAddress).balanceOf(address(tokenGenerator)),
                INITIAL_TOKEN_SUPPLY + startingTokenSupply + amounts[i]
            );
            uint256 endingEthBalance = address(tokenGenerator).balance;
            assertEq(endingEthBalance, startingEthBalance + totalCost);

            // check buyer data
            assertEq(
                tokenGenerator.getBuyerTokenAmountPurchased(
                    tokenAddress,
                    buyers[i]
                ),
                amounts[i]
            );
            assertEq(
                tokenGenerator.getBuyerEthAmountSpent(tokenAddress, buyers[i]),
                totalCost
            );
        }
    }

    function testShouldChangeTheFundingActiveStatusToTrueAfterMaxSupplyReachedSinglePurchase()
        public
    {
        createToken();

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), false);

        purchaseMaxSupplyOfTokens();

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), true);
    }

    function testShouldChangeTheFundingActiveStatusToTrueAfterMaxSupplyReachedMultiplePurchases()
        public
    {
        createToken();

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), false);

        address[4] memory buyers = [BUYER, BUYER2, BUYER3, BUYER4];
        uint24[4] memory amounts = [200000, 300000, 100000, 200000];

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

            // purchase
            console.log("------------------- PURCHASE -------------------", i);
            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalCost}(
                tokenAddress,
                amounts[i]
            );

            if (
                tokenGenerator.getCurrentSupplyWithoutInitialSupply(
                    tokenAddress
                ) != MAX_SUPPLY_WITHOUT_INIT_SUPPLY
            ) {
                assertEq(
                    tokenGenerator.getTokenFundingComplete(tokenAddress),
                    false
                );
            } else {
                assertEq(
                    tokenGenerator.getTokenFundingComplete(tokenAddress),
                    true
                );
            }
        }
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

            // Token contract should have 0 tokens and 0 ETH
            assertEq(address(tokenAddress).balance, 0);
            assertEq(Token(tokenAddress).balanceOf(tokenAddress), 0);
        }
    }

    function testShouldEmitEventAfterPurchasingTokensNotMaxPurchase() public {
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
        vm.expectEmit(true, true, true, true);
        // funding should not be active (returns false)
        emit TokenPurchase(
            tokenAddress,
            TOKEN_AMOUNT_ONE,
            BUYER,
            totalPrice,
            false
        );
        tokenGenerator.purchaseToken{value: totalPrice}(
            tokenAddress,
            TOKEN_AMOUNT_ONE
        );
    }

    function testShouldEmitEventAfterPurchasingTokensWithMaxPurchase() public {
        createToken();

        uint256 maxTokenAmount = 800000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            maxTokenAmount
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            maxTokenAmount,
            newStage
        );

        vm.prank(BUYER);
        vm.expectEmit(true, true, true, true);
        // funding should be active (returns true)
        emit TokenPurchase(
            tokenAddress,
            maxTokenAmount,
            BUYER,
            totalPrice,
            true
        );
        tokenGenerator.purchaseToken{value: totalPrice}(
            tokenAddress,
            maxTokenAmount
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

        // check if total price reaches the fund goal
        assertEq(totalPriceAccumulated, TOKEN_FUND_GOAL);
    }

    function testShouldCalculatePriceForTokensPlusOne() public {
        createToken();

        // TOKEN_AMOUNT_THREE = 200000 which is stage 0
        // 200000 + 1 is exactly the beggining of next stage 1
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

        // spanning to stage 3
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

        uint256 stagePrice0 = 200000 * 3000000000000;
        console.log("Stage price1:", stagePrice0);
        uint256 stagePrice1 = 200000 * 4500000000000;
        console.log("Stage price2:", stagePrice1);
        uint256 stagePrice2 = 100000 * 7500000000000;
        console.log("Stage price3:", stagePrice2);
        uint256 stagePrice3 = 25000 * 20000000000000;
        console.log("Stage price4:", stagePrice3);

        assertEq(
            totalPrice,
            stagePrice0 + stagePrice1 + stagePrice2 + stagePrice3
        );
    }

    function testShouldCalculateTotalPriceWithinTheSameStagePurchase() public {
        createToken();

        // sum of this tokens is still in the same stage 0
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

            // directly using array in assert sometimes causes overflow/underflow inside of test calculation
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

    function testFuzz_ShouldEndUpWithFundGoalOfEthIfMaxSupplyReached(
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

    /////////////////////////////////////
    // withdrawFailedLaunchFunds TESTs //
    /////////////////////////////////////
    function testShouldRevertIfAddressIsZeroAddress() public {
        createToken();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ZeroAddressNotAllowed.selector
            )
        );
        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(address(0));
    }

    // 4 possibilities:
    // Funding complete / deadline not reached =        REVERT
    // Funding complete / deadline reached =            REVERT
    // Funding not complete / deadline not reached =    REVERT
    // Funding not complete / deadline reached =        NOT REVERT
    function testShouldRevertIfFundingIsCompleteAndDeadlineNotReached() public {
        createToken();

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), false);
        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), false);

        uint256 tokenAmount = 800000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

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

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), true);
        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), false);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__TokenFundingComplete.selector
            )
        );
        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);
    }

    function testShouldRevertIfFundingIsCompleteAndDeadlineReached() public {
        createToken();

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), false);
        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), false);

        uint256 tokenAmount = 800000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

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

        vm.warp(block.timestamp + icoDeadlineInDays * ONE_DAY_IN_SECONDS + 1);
        vm.roll(block.number + 1);

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), true);
        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), true);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__TokenFundingComplete.selector
            )
        );
        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);
    }

    function testShouldRevertIfFundingIsNotCompleteAndDeadlineNotReached()
        public
    {
        createToken();

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), false);
        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), false);

        uint256 tokenAmount = 700000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

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

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), false);
        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), false);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__TokenSaleActive.selector
            )
        );
        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);
    }

    function testShouldNotRevertIfFundingIsNotCompleteAndDeadlineReached()
        public
    {
        createToken();

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), false);
        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), false);

        uint256 tokenAmount = 700000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

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

        vm.warp(block.timestamp + icoDeadlineInDays * ONE_DAY_IN_SECONDS + 1);
        vm.roll(block.number + 1);

        assertEq(tokenGenerator.getTokenFundingComplete(tokenAddress), false);
        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), true);

        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);
    }

    function testShouldRevertIfAlreadyWithdrawed() public {
        createToken();

        uint256 tokenAmount = 150000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

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

        vm.warp(block.timestamp + icoDeadlineInDays * ONE_DAY_IN_SECONDS + 1);
        vm.roll(block.number + 1);

        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__NoEthToWithdraw.selector
            )
        );
        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);
    }

    function testShouldRevertIfWithdrawingFromInvalidAddress() public {
        createToken();

        uint256 tokenAmount = 150000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

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

        vm.warp(block.timestamp + icoDeadlineInDays * ONE_DAY_IN_SECONDS + 1);
        vm.roll(block.number + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__NoEthToWithdraw.selector
            )
        );
        // calling from address BUYER2 which didnt purchase any tokens
        vm.prank(BUYER2);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);
    }

    function testShouldWihtdrawExactAmountWithSinglePurchaseAndUpdateData()
        public
    {
        createToken();

        assertEq(tokenGenerator.getBuyerEthAmountSpent(tokenAddress, BUYER), 0);

        uint256 tokenAmount = 150000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

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

        assertEq(
            tokenGenerator.getBuyerEthAmountSpent(tokenAddress, BUYER),
            totalPrice
        );

        vm.warp(block.timestamp + icoDeadlineInDays * ONE_DAY_IN_SECONDS + 1);
        vm.roll(block.number + 1);

        uint256 startingBalance = address(BUYER).balance;

        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);

        uint256 endingBalance = address(BUYER).balance;

        assertEq(endingBalance, startingBalance + totalPrice);
        assertEq(tokenGenerator.getBuyerEthAmountSpent(tokenAddress, BUYER), 0);
    }

    function testShouldWihtdrawExactAmountWithMultiplePurchasesAndUpdateData()
        public
    {
        createToken();

        uint24[3] memory amounts = [150000, 5000, 125000];

        uint256 totalPriceAccumulated;

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = amounts[i];

            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                amount
            );

            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                amount,
                newStage
            );

            totalPriceAccumulated += totalPrice;

            vm.prank(BUYER);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amount
            );

            assertEq(
                tokenGenerator.getBuyerEthAmountSpent(tokenAddress, BUYER),
                totalPriceAccumulated
            );
        }

        vm.warp(block.timestamp + icoDeadlineInDays * ONE_DAY_IN_SECONDS + 1);
        vm.roll(block.number + 1);

        uint256 startingBalance = address(BUYER).balance;

        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);

        uint256 endingBalance = address(BUYER).balance;

        assertEq(endingBalance, startingBalance + totalPriceAccumulated);
        assertEq(tokenGenerator.getBuyerEthAmountSpent(tokenAddress, BUYER), 0);
    }

    function testShouldWithdrawExactAmountWithMultipleTokensPurchases() public {
        vm.prank(TOKEN_OWNER);
        address tokenAddress1 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL
        );
        vm.prank(TOKEN_OWNER);
        address tokenAddress2 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME2,
            TOKEN_SYMBOL2
        );
        vm.prank(TOKEN_OWNER);
        address tokenAddress3 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME2,
            TOKEN_SYMBOL2
        );

        uint24[3] memory amounts = [120000, 250000, 13000];
        address[3] memory tokenAddresses = [
            tokenAddress1,
            tokenAddress2,
            tokenAddress3
        ];

        uint256 totalPriceAccumulated;

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = amounts[i];
            address newTokenAddress = tokenAddresses[i];

            uint256 newStage = tokenGenerator.calculateNewStage(
                newTokenAddress,
                amount
            );

            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                newTokenAddress,
                amount,
                newStage
            );

            totalPriceAccumulated += totalPrice;

            vm.prank(BUYER);
            tokenGenerator.purchaseToken{value: totalPrice}(
                newTokenAddress,
                amount
            );

            assertEq(
                tokenGenerator.getBuyerEthAmountSpent(newTokenAddress, BUYER),
                totalPrice
            );
        }

        vm.warp(block.timestamp + icoDeadlineInDays * ONE_DAY_IN_SECONDS + 1);
        vm.roll(block.number + 1);

        uint256 balanceBeforeWithdraw = address(BUYER).balance;

        for (uint256 j = 0; j < 3; j++) {
            uint256 startingBalance = address(BUYER).balance;

            uint256 expectedEthToWithdraw = tokenGenerator
                .getBuyerEthAmountSpent(tokenAddresses[j], BUYER);

            vm.prank(BUYER);
            tokenGenerator.withdrawFailedLaunchFunds(tokenAddresses[j]);

            uint256 endingBalance = address(BUYER).balance;

            assertEq(endingBalance, startingBalance + expectedEthToWithdraw);
            assertEq(
                tokenGenerator.getBuyerEthAmountSpent(tokenAddresses[j], BUYER),
                0
            );
        }

        assertEq(
            address(BUYER).balance,
            balanceBeforeWithdraw + totalPriceAccumulated
        );
    }

    function testShouldEmitEventBuyerFundsWithdrawn() public {
        createToken();

        uint256 tokenAmount = 150000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

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

        vm.warp(block.timestamp + icoDeadlineInDays * ONE_DAY_IN_SECONDS + 1);
        vm.roll(block.number + 1);

        vm.expectEmit(true, true, true, false);
        emit BuyerFundsWithdrawn(tokenAddress, BUYER, totalPrice);
        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(tokenAddress);
    }

    ///////////////////////////////////
    // withdrawAccumulatedFees TESTs //
    ///////////////////////////////////
    function testShouldRevertIfCalledByNotOwnerAndBalanceShouldNotChange()
        public
    {
        address[4] memory notOwnerAddresses = [
            BUYER,
            TOKEN_OWNER,
            BUYER2,
            TOKEN_OWNER2
        ];

        vm.prank(TOKEN_OWNER);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);

        uint256 startingBalance1 = address(tokenGenerator).balance;

        for (uint256 i = 0; i < notOwnerAddresses.length; i++) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    TokenGenerator.TokenGenerator__OnlyOwner.selector
                )
            );
            vm.prank(notOwnerAddresses[i]);
            tokenGenerator.withdrawAccumulatedFees();
        }

        uint256 endingBalance1 = address(tokenGenerator).balance;

        assertEq(startingBalance1, endingBalance1);

        vm.prank(TOKEN_OWNER2);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME2, TOKEN_SYMBOL2);

        vm.prank(TOKEN_OWNER3);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME3, TOKEN_SYMBOL3);

        uint256 startingBalance2 = address(tokenGenerator).balance;

        for (uint256 i = 0; i < notOwnerAddresses.length; i++) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    TokenGenerator.TokenGenerator__OnlyOwner.selector
                )
            );
            vm.prank(notOwnerAddresses[i]);
            tokenGenerator.withdrawAccumulatedFees();
        }

        uint256 endingBalance2 = address(tokenGenerator).balance;

        assertEq(startingBalance2, endingBalance2);
    }

    function testShouldWithdrawExactAmountOfFeesFromContractToOwnerAddress()
        public
    {
        address ownerAddress = tokenGenerator.getOwnerAddress();
        address tokenGeneratorAddress = address(tokenGenerator);

        uint256 startingOwnerBalance1 = ownerAddress.balance;
        console.log("Owner startingBalance1:", startingOwnerBalance1);

        // create token #1
        vm.prank(TOKEN_OWNER);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);

        uint256 startingContractBalance1 = tokenGeneratorAddress.balance;
        console.log("Contract startingBalance1:", startingContractBalance1);

        // withdraw fees #1
        vm.prank(ownerAddress);
        tokenGenerator.withdrawAccumulatedFees();

        uint256 endingOwnerBalance1 = ownerAddress.balance;
        uint256 endingContractBalance1 = tokenGeneratorAddress.balance;
        console.log("Owner endingOwnerBalance1:", endingOwnerBalance1);
        console.log("Contract endingContractBalance1:", endingContractBalance1);

        if (block.chainid == 1) {
            console.log(
                "*** Test skipped on Fork (Owner address fallback error, works on Anvil) ***"
            );
            return;
        } else {
            assertEq(endingOwnerBalance1, startingOwnerBalance1 + fee);
        }

        assertEq(endingContractBalance1, startingContractBalance1 - fee);

        console.log(
            "----------------------------------------------------------------"
        );

        uint256 startingOwnerBalance2 = ownerAddress.balance;
        console.log("Owner startingOwnerBalance2:", startingOwnerBalance2);

        // create tokens #2 and #3
        vm.prank(TOKEN_OWNER2);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME2, TOKEN_SYMBOL2);

        vm.prank(TOKEN_OWNER3);
        tokenGenerator.createToken{value: fee}(TOKEN_NAME3, TOKEN_SYMBOL3);

        uint256 startingContractBalance2 = tokenGeneratorAddress.balance;
        console.log(
            "Owner startingContractBalance2:",
            startingContractBalance2
        );

        // withdraw fees #2
        vm.prank(ownerAddress);
        tokenGenerator.withdrawAccumulatedFees();

        uint256 endingOwnerBalance2 = ownerAddress.balance;
        uint256 endingContractBalance2 = tokenGeneratorAddress.balance;
        console.log("Owner endingOwnerBalance2:", endingOwnerBalance2);
        console.log("Contract endingContractBalance2:", endingContractBalance2);

        if (block.chainid == 1) {
            console.log(
                "*** Test skipped on Fork (Owner address fallback error, works on Anvil) ***"
            );
            return;
        } else {
            assertEq(endingOwnerBalance2, startingOwnerBalance2 + (2 * fee));
        }
        assertEq(endingContractBalance2, startingContractBalance2 - (2 * fee));
    }

    function testShouldWithdrawExactAmountWithMultiplePurchases() public {
        createTokenAndPurchaseMultipleBuyers();

        address ownerAddress = tokenGenerator.getOwnerAddress();
        address tokenGeneratorAddress = address(tokenGenerator);

        uint256 startingOwnerBalance = ownerAddress.balance;
        console.log("Owner startingOwnerBalance:", startingOwnerBalance);

        uint256 startingContractBalance = tokenGeneratorAddress.balance;
        console.log(
            "Contract startingContractBalance:",
            startingContractBalance
        );

        // withdraw fees
        vm.prank(ownerAddress);
        tokenGenerator.withdrawAccumulatedFees();

        uint256 endingOwnerBalance = ownerAddress.balance;
        uint256 endingContractBalance = tokenGeneratorAddress.balance;
        console.log("Owner endingOwnerBalance:", endingOwnerBalance);
        console.log("Contract endingContractBalance:", endingContractBalance);

        if (block.chainid == 1) {
            console.log(
                "*** Test skipped on Fork (Owner address fallback error, works on Anvil) ***"
            );
            return;
        } else {
            assertEq(endingOwnerBalance, startingOwnerBalance + fee);
        }

        assertEq(endingContractBalance, startingContractBalance - fee);
    }

    function testShouldWithdrawExactAmountWithMultiplePurchasesAndMultipleTokens()
        public
    {
        address[3] memory buyers = [BUYER, BUYER2, BUYER3];

        address ownerAddress = tokenGenerator.getOwnerAddress();
        address tokenGeneratorAddress = address(tokenGenerator);

        uint256 pricePaidByBuyersAccumulated;

        for (uint256 i = 0; i < buyers.length; i++) {
            address newTokenAddress = tokenGenerator.createToken{value: fee}(
                TOKEN_NAME,
                TOKEN_SYMBOL
            );

            uint256 tokenAmount = 150000;

            uint256 newStage = tokenGenerator.calculateNewStage(
                newTokenAddress,
                tokenAmount
            );

            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                newTokenAddress,
                tokenAmount,
                newStage
            );

            pricePaidByBuyersAccumulated += totalPrice;

            vm.prank(buyers[i]);
            tokenGenerator.purchaseToken{value: totalPrice}(
                newTokenAddress,
                tokenAmount
            );
        }

        uint256 startingOwnerBalance = ownerAddress.balance;
        console.log("Owner startingOwnerBalance:", startingOwnerBalance);

        uint256 startingContractBalance = tokenGeneratorAddress.balance;
        console.log(
            "Contract startingContractBalance:",
            startingContractBalance
        );

        // withdraw fees
        vm.prank(ownerAddress);
        tokenGenerator.withdrawAccumulatedFees();

        uint256 endingOwnerBalance = ownerAddress.balance;
        uint256 endingContractBalance = tokenGeneratorAddress.balance;
        console.log("Owner endingOwnerBalance:", endingOwnerBalance);
        console.log("Contract endingContractBalance:", endingContractBalance);

        if (block.chainid == 1) {
            console.log(
                "*** Test skipped on Fork (Owner address fallback error, works on Anvil) ***"
            );
            return;
        } else {
            assertEq(
                endingOwnerBalance,
                startingOwnerBalance + (buyers.length * fee)
            );
        }

        assertEq(
            endingContractBalance,
            startingContractBalance - (buyers.length * fee)
        );
        assertEq(endingContractBalance, pricePaidByBuyersAccumulated);
    }

    function testShouldEmitEventFeesWithdrawed() public {
        createToken();

        address ownerAddress = tokenGenerator.getOwnerAddress();

        assertEq(fee, tokenGenerator.getAccumulatedFees());

        vm.expectEmit(true, true, false, false);
        emit FeesWithdrawed(ownerAddress, fee);
        vm.prank(ownerAddress);
        tokenGenerator.withdrawAccumulatedFees();
    }

    /////////////////////////////
    // transferOwnership TESTs //
    /////////////////////////////
    function testShouldRevertIfNotCalledByOwner() public {
        address[4] memory notOwnerAddresses = [
            BUYER,
            TOKEN_OWNER,
            BUYER2,
            TOKEN_OWNER2
        ];

        for (uint256 i = 0; i < notOwnerAddresses.length; i++) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    TokenGenerator.TokenGenerator__OnlyOwner.selector
                )
            );
            vm.prank(notOwnerAddresses[i]);
            tokenGenerator.transferOwnership(BUYER3);
        }
    }

    function testShouldRevertIfNewOwnerIsZeroAddress() public {
        address ownerAddress = tokenGenerator.getOwnerAddress();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ZeroAddressNotAllowed.selector
            )
        );
        vm.prank(ownerAddress);
        tokenGenerator.transferOwnership(address(0));
    }

    function testShouldChangeOwnerAddressToNewOwnerAddressAndEmitEvent()
        public
    {
        createToken();

        address previousOwner = tokenGenerator.getOwnerAddress();
        address newOwner = BUYER4;

        vm.prank(newOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__OnlyOwner.selector
            )
        );
        tokenGenerator.withdrawAccumulatedFees();

        assertEq(tokenGenerator.getOwnerAddress(), previousOwner);

        vm.expectEmit(true, true, false, false);
        emit OwnerAddressChanged(previousOwner, newOwner);
        vm.prank(previousOwner);
        tokenGenerator.transferOwnership(newOwner);

        assertEq(tokenGenerator.getOwnerAddress(), newOwner);

        vm.prank(newOwner);
        tokenGenerator.withdrawAccumulatedFees();
    }

    ///////////////////////
    // claimTokens TESTs //
    ///////////////////////
    function testShouldRevertIfProvidedAddressIsZeroAddress() public {
        createTokenAndMaxPurchase();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__ZeroAddressNotAllowed.selector
            )
        );
        vm.prank(BUYER);
        tokenGenerator.claimTokens(address(0));
    }

    function testShouldRevertIfTokenICOIsNotActive() public {
        createTokenAndMaxPurchase();

        assertEq(tokenGenerator.getTokenICOStatus(tokenAddress), false);
        assertGt(
            tokenGenerator.getBuyerTokenAmountPurchased(tokenAddress, BUYER),
            0
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__TokenICONotActive.selector
            )
        );
        vm.prank(BUYER);
        tokenGenerator.claimTokens(tokenAddress);
    }

    function testShouldRevertIfTokenAmoutPurchasedIsZero_ZeroPurchasesFromBuyer()
        public
    {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }

        createTokenAndMaxPurchase();

        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        assertEq(
            tokenGenerator.getBuyerTokenAmountPurchased(tokenAddress, BUYER4),
            0
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__NoTokensLeft.selector
            )
        );
        vm.prank(BUYER4);
        tokenGenerator.claimTokens(tokenAddress);
    }

    function testShouldRevertIfTokenAmoutPurchasedIsZero_AlreadyClaimed()
        public
    {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        createTokenAndMaxPurchase();

        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        // claim tokens
        vm.prank(BUYER);
        tokenGenerator.claimTokens(tokenAddress);

        // claim again
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__NoTokensLeft.selector
            )
        );
        vm.prank(BUYER);
        tokenGenerator.claimTokens(tokenAddress);
    }

    function testShouldResetTheTokenAmountPurchasedToZero() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        createTokenAndMaxPurchase();

        assertEq(
            tokenGenerator.getBuyerTokenAmountPurchased(tokenAddress, BUYER),
            TOKEN_AMOUNT_ONE
        );

        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        vm.prank(BUYER);
        tokenGenerator.claimTokens(tokenAddress);

        assertEq(
            tokenGenerator.getBuyerTokenAmountPurchased(tokenAddress, BUYER),
            0
        );
    }

    function testShouldSendTokensFromContractToBuyer() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        createTokenAndMaxPurchase();

        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        uint256 startingTokenAmountBuyer = Token(tokenAddress).balanceOf(BUYER);
        uint256 startingTokenAmountContract = Token(tokenAddress).balanceOf(
            address(tokenGenerator)
        );

        vm.prank(BUYER);
        tokenGenerator.claimTokens(tokenAddress);

        uint256 endingTokenAmountBuyer = Token(tokenAddress).balanceOf(BUYER);
        uint256 endingTokenAmountContract = Token(tokenAddress).balanceOf(
            address(tokenGenerator)
        );

        assertEq(
            endingTokenAmountBuyer,
            startingTokenAmountBuyer + TOKEN_AMOUNT_ONE
        );
        assertEq(
            endingTokenAmountContract,
            startingTokenAmountContract - TOKEN_AMOUNT_ONE
        );
    }

    function testShouldEmitEvent() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        createTokenAndMaxPurchase();

        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        vm.prank(BUYER);
        vm.expectEmit(true, true, true, false);
        emit TokensClaimed(tokenAddress, BUYER, TOKEN_AMOUNT_ONE);
        tokenGenerator.claimTokens(tokenAddress);
    }

    ////////////////////////////////////////////////////
    // createPoolAndAddLiquidityAndBurnLPTokens TESTs //
    ////////////////////////////////////////////////////
    function testShouldRevertIfFundingIsNotActiveNoPurchase() public {
        createToken();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__FundingNotComplete.selector
            )
        );
        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);
    }

    function testShouldRevertIfFundingIsNotActiveSinglePurchase() public {
        createTokenAndPurchaseOneBuyer();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__FundingNotComplete.selector
            )
        );
        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);
    }

    function testShouldRevertIfFundingIsNotActiveMultiplePurchases() public {
        createTokenAndPurchaseMultipleBuyers();

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__FundingNotComplete.selector
            )
        );
        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);
    }

    function testShouldRevertIfICOAlreadyActive() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        createTokenAndMaxPurchase();

        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGenerator.TokenGenerator__TokenICOActive.selector
            )
        );
        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);
    }

    // cant be directly tested because funding will not be active if the fund goal is not met
    // function testShouldRevertIfFundingGoalIsNotMet() public {
    // }

    function testShouldNotRevertIfTheLiqudityPoolIsAlreadyCreated() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapV2FactoryAddress);

        createToken();

        // create liqudity pool before calling the "createPoolAndAddLiquidityAndBurnLPTokens" function
        address poolAddress = factory.createPair(tokenAddress, weth);

        purchaseMaxSupplyOfTokens();

        uint256 startingTokenGeneratorETHBalance = address(tokenGenerator)
            .balance;
        uint256 startingWethContractBalance = weth.balance;
        uint256 fundedEth = tokenGenerator.getTokenEthAmountFunded(
            tokenAddress
        );

        assertEq(poolAddress, factory.getPair(tokenAddress, weth));

        (address returnedPoolAddress, uint256 liqudity) = tokenGenerator
            .createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        uint256 endingTokenGeneratorETHBalance = address(tokenGenerator)
            .balance;

        uint256 endingWethContractBalance = weth.balance;

        assertEq(poolAddress, returnedPoolAddress);
        assertGt(liqudity, 0);
        assertEq(
            IUniswapV2Pair(poolAddress).balanceOf(address(tokenGenerator)),
            0
        );
        assertEq(Token(tokenAddress).balanceOf(poolAddress), 200000);
        assertEq(
            Token(tokenAddress).balanceOf(address(tokenGenerator)),
            MAX_SUPPLY_WITHOUT_INIT_SUPPLY
        );
        assertEq(
            startingTokenGeneratorETHBalance - fundedEth,
            endingTokenGeneratorETHBalance
        );
        assertEq(
            startingWethContractBalance + fundedEth,
            endingWethContractBalance
        );
    }

    function testShoulResetTheETHFundedToZeroAfterSuccessfullCall() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        createTokenAndMaxPurchase();

        assertEq(
            tokenGenerator.getTokenEthAmountFunded(tokenAddress),
            TOKEN_FUND_GOAL
        );

        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        assertEq(tokenGenerator.getTokenEthAmountFunded(tokenAddress), 0);
    }

    function testShouldCreatePoolAddLiqudityAndBurnLPTokens() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapV2FactoryAddress);

        createToken();

        // works either way the addresses are inputed
        assertEq(factory.getPair(tokenAddress, weth), address(0));

        purchaseMaxSupplyOfTokens();

        uint256 startingTokenGeneratorETHBalance = address(tokenGenerator)
            .balance;
        uint256 startingWethContractBalance = weth.balance;
        uint256 fundedEth = tokenGenerator.getTokenEthAmountFunded(
            tokenAddress
        );

        (address returnPoolAddress, ) = tokenGenerator
            .createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        address poolAddress = factory.getPair(tokenAddress, weth);

        uint256 endingTokenGeneratorETHBalance = address(tokenGenerator)
            .balance;

        uint256 endingWethContractBalance = weth.balance;

        assertEq(returnPoolAddress, poolAddress);
        assertEq(
            Token(tokenAddress).balanceOf(address(tokenGenerator)),
            MAX_SUPPLY_WITHOUT_INIT_SUPPLY
        );
        assertEq(
            startingTokenGeneratorETHBalance - fundedEth,
            endingTokenGeneratorETHBalance
        );
        assertEq(Token(tokenAddress).balanceOf(poolAddress), 200000);
        assertEq(
            IUniswapV2Pair(poolAddress).balanceOf(address(tokenGenerator)),
            0
        );
        assertEq(
            startingWethContractBalance + fundedEth,
            endingWethContractBalance
        );
    }

    function testShouldEmitAnEvent() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        createTokenAndMaxPurchase();

        address pair;

        address wethAddress = IUniswapV2Router02(uniswapV2RouterAddress).WETH();

        (address token0, address token1) = tokenAddress < wethAddress
            ? (tokenAddress, wethAddress)
            : (wethAddress, tokenAddress);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        bytes32 hash = keccak256(
            abi.encodePacked(
                hex"ff",
                uniswapV2FactoryAddress,
                salt,
                hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // UniswapV2Pair bytecode hash
            )
        );
        pair = address(uint160(uint256(hash)));
        console.log(pair);

        vm.expectEmit(true, true, true, false);

        emit PoolCreatedliquidityAddedLPTokensBurned(
            tokenAddress,
            pair,
            2049390152191
        );
        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);
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
    function testShouldGetCurrentSupplyWithoutInitialSupply() public {
        createToken();

        uint256 startingSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        assertEq(startingSupply, 0);

        uint256 tokenAmount = 150000;

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            tokenAmount
        );

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

        uint256 endingSupply = tokenGenerator
            .getCurrentSupplyWithoutInitialSupply(tokenAddress);

        assertEq(endingSupply, tokenAmount);
    }

    //////////////////////////////////////
    // getElapsedTimeSinceCreation TEST //
    //////////////////////////////////////
    function testShouldGetTimeElapsedSinceTokenCreation() public {
        createToken();

        assertEq(tokenGenerator.getElapsedTimeSinceCreation(tokenAddress), 0);

        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + 1);

        assertEq(
            tokenGenerator.getElapsedTimeSinceCreation(tokenAddress),
            5 days
        );
    }

    ////////////////////////////////////
    // getTokenCreationTimestamp TEST //
    ////////////////////////////////////
    function testShouldReturnTheTimestampWhenTheTokenWasCreated() public {
        createToken();

        uint256 timeStamp = block.timestamp;

        assertEq(
            tokenGenerator.getTokenCreationTimestamp(tokenAddress),
            timeStamp
        );
    }

    ////////////////////////////
    // getTokenICOStatus TEST //
    ////////////////////////////
    function testShouldReturnICOStatus() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        createToken();

        assertEq(tokenGenerator.getTokenICOStatus(tokenAddress), false);

        purchaseMaxSupplyOfTokens();

        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        assertEq(tokenGenerator.getTokenICOStatus(tokenAddress), true);
    }

    //////////////////////////////////
    // getCurrentPricingStage TESTs //
    //////////////////////////////////
    function testShouldGetTheCurrentPricingStage() public {
        createToken();

        assertEq(tokenGenerator.getCurrentPricingStage(tokenAddress), 0);

        uint24[4] memory amounts = [200000, 200000, 100000, 50000];

        for (uint256 i = 0; i < amounts.length; i++) {
            assertEq(tokenGenerator.getCurrentPricingStage(tokenAddress), i);

            uint256 amount = amounts[i];

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
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                amount
            );

            assertEq(
                tokenGenerator.getCurrentPricingStage(tokenAddress),
                i + 1
            );
        }
    }

    //////////////////////////////////
    // isTokenDeadlineExpired TESTs //
    //////////////////////////////////
    function testShouldReturnIfDeadlineWasExpiredOrNot() public {
        createToken();

        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), false);

        vm.warp(block.timestamp + (icoDeadlineInDays * ONE_DAY_IN_SECONDS));
        vm.roll(block.number + 1);

        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), false);

        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        assertEq(tokenGenerator.isTokenDeadlineExpired(tokenAddress), true);
    }

    /////////////////////////////
    // getAccumulatedFees TEST //
    /////////////////////////////
    function testShouldReturnAccumulatedFees() public {
        assertEq(tokenGenerator.getAccumulatedFees(), 0);

        createToken();

        assertEq(tokenGenerator.getAccumulatedFees(), fee);

        purchaseMaxSupplyOfTokens();

        assertEq(tokenGenerator.getAccumulatedFees(), fee);

        tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);

        assertEq(tokenGenerator.getAccumulatedFees(), fee * 2);

        address owner = tokenGenerator.getOwnerAddress();
        vm.prank(owner);
        tokenGenerator.withdrawAccumulatedFees();

        assertEq(tokenGenerator.getAccumulatedFees(), 0);
    }

    ////////////////////////
    // getStagePrice TEST //
    ////////////////////////
    function testShouldReturnStagePrice() public {
        createToken();

        uint48[8] memory stagePrices = [
            3000000000000, //   0.000003  ETH per token
            4500000000000, //   0.0000045 ETH per token
            7500000000000, //   0.0000075 ETH per token
            20000000000000, //  0.00002   ETH per token
            35000000000000, //  0.000035  ETH per token
            55000000000000, //  0.000055  ETH per token
            75000000000000, //  0.000075  ETH per token
            95000000000000 //   0.000095  ETH per token
        ];

        for (uint256 i = 0; i < stagePrices.length; i++) {
            uint256 stagePrice = stagePrices[i];

            assertEq(tokenGenerator.getStagePrice(i), stagePrice);
        }
    }

    /////////////////////////
    // getStageSupply TEST //
    /////////////////////////
    function testShouldReturnStageSupply() public {
        createToken();

        uint24[8] memory stageSupplies = [
            200000, //  Stage 0: 0    - 200k tokens (0.6  ETH total cost)
            400000, //  Stage 1: 200k - 400k tokens (0.9  ETH total cost)
            500000, //  Stage 2: 400k - 500k tokens (0.75 ETH total cost)
            550000, //  Stage 3: 500k - 550k tokens (1    ETH total cost)
            600000, //  Stage 4: 550k - 600k tokens (1.75 ETH total cost)
            650000, //  Stage 5: 600k - 650k tokens (2.75 ETH total cost)
            700000, //  Stage 6: 650k - 700k tokens (3.75 ETH total cost)
            800000 //   Stage 7: 700k - 800k tokens (9.5  ETH total cost)
        ];

        for (uint256 i = 0; i < stageSupplies.length; i++) {
            uint256 stageSupply = stageSupplies[i];

            assertEq(tokenGenerator.getStageSupply(i), stageSupply);
        }
    }

    //////////////////////////
    // getTokenCreator TEST //
    //////////////////////////
    function testShouldReturnTheTokenCreator() public {
        vm.prank(TOKEN_OWNER);
        address token1 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL
        );

        assertEq(tokenGenerator.getTokenCreator(token1), TOKEN_OWNER);

        vm.prank(TOKEN_OWNER2);
        address token2 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL
        );

        assertEq(tokenGenerator.getTokenCreator(token2), TOKEN_OWNER2);

        vm.prank(TOKEN_OWNER3);
        address token3 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL
        );

        assertEq(tokenGenerator.getTokenCreator(token3), TOKEN_OWNER3);
    }

    /////////////////////////////////////
    // getTokenCurrentStageSupply TEST //
    /////////////////////////////////////
    function testShouldReturnCurrentStageSupply() public {
        createToken();

        uint24[8] memory stageSupplies = [
            200000, //  Stage 0: 0    - 200k tokens (0.6  ETH total cost)
            400000, //  Stage 1: 200k - 400k tokens (0.9  ETH total cost)
            500000, //  Stage 2: 400k - 500k tokens (0.75 ETH total cost)
            550000, //  Stage 3: 500k - 550k tokens (1    ETH total cost)
            600000, //  Stage 4: 550k - 600k tokens (1.75 ETH total cost)
            650000, //  Stage 5: 600k - 650k tokens (2.75 ETH total cost)
            700000, //  Stage 6: 650k - 700k tokens (3.75 ETH total cost)
            800000 //   Stage 7: 700k - 800k tokens (9.5  ETH total cost)
        ];

        for (uint256 i = 0; i < stageSupplies.length; i++) {
            uint256 stageSupply = stageSupplies[i];

            assertEq(
                tokenGenerator.getTokenCurrentStageSupply(tokenAddress),
                stageSupply
            );

            uint256 currentSupply = tokenGenerator
                .getCurrentSupplyWithoutInitialSupply(tokenAddress);

            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                stageSupply - currentSupply
            );

            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                stageSupply - currentSupply,
                newStage
            );

            vm.prank(BUYER);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                stageSupply - currentSupply
            );

            if (i < 7) {
                assertEq(
                    tokenGenerator.getTokenCurrentStageSupply(tokenAddress),
                    stageSupplies[i + 1]
                );
            }
        }
    }

    ////////////////////////////////////
    // getTokenCurrentStagePrice TEST //
    ////////////////////////////////////
    function testShouldReturnCurrentStagePrice() public {
        createToken();

        uint48[8] memory stagePrices = [
            3000000000000, //   0.000003  ETH per token
            4500000000000, //   0.0000045 ETH per token
            7500000000000, //   0.0000075 ETH per token
            20000000000000, //  0.00002   ETH per token
            35000000000000, //  0.000035  ETH per token
            55000000000000, //  0.000055  ETH per token
            75000000000000, //  0.000075  ETH per token
            95000000000000 //   0.000095  ETH per token
        ];

        uint24[8] memory stageSupplies = [
            200000, //  Stage 0: 0    - 200k tokens (0.6  ETH total cost)
            400000, //  Stage 1: 200k - 400k tokens (0.9  ETH total cost)
            500000, //  Stage 2: 400k - 500k tokens (0.75 ETH total cost)
            550000, //  Stage 3: 500k - 550k tokens (1    ETH total cost)
            600000, //  Stage 4: 550k - 600k tokens (1.75 ETH total cost)
            650000, //  Stage 5: 600k - 650k tokens (2.75 ETH total cost)
            700000, //  Stage 6: 650k - 700k tokens (3.75 ETH total cost)
            800000 //   Stage 7: 700k - 800k tokens (9.5  ETH total cost)
        ];

        for (uint256 i = 0; i < stagePrices.length; i++) {
            uint256 stagePrice = stagePrices[i];
            uint256 stageSupply = stageSupplies[i];

            assertEq(tokenGenerator.getStagePrice(i), stagePrice);

            uint256 currentSupply = tokenGenerator
                .getCurrentSupplyWithoutInitialSupply(tokenAddress);

            uint256 newStage = tokenGenerator.calculateNewStage(
                tokenAddress,
                stageSupply - currentSupply
            );

            uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
                tokenAddress,
                stageSupply - currentSupply,
                newStage
            );

            vm.prank(BUYER);
            tokenGenerator.purchaseToken{value: totalPrice}(
                tokenAddress,
                stageSupply - currentSupply
            );

            if (i < 7) {
                assertEq(tokenGenerator.getStagePrice(i), stagePrices[i]);
            }
        }
    }

    //////////////////////////////////
    // getAvailableStageSupply TEST //
    //////////////////////////////////
    function testFuzz_ShouldReturnRemainingSupplyInCurrentStage(
        uint256 _amount
    ) public {
        uint256 amount = bound(_amount, 1, 199999);

        createToken();

        assertEq(tokenGenerator.getAvailableStageSupply(tokenAddress), 200000);

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

        assertEq(
            tokenGenerator.getAvailableStageSupply(tokenAddress),
            200000 - amount
        );
    }

    ///////////////////////////////
    // getTotalTokensAmount TEST //
    ///////////////////////////////
    function testShouldReturnAmountOfTokensCreated() public {
        for (uint256 i = 1; i < 10; i++) {
            vm.prank(TOKEN_OWNER);
            tokenGenerator.createToken{value: fee}(TOKEN_NAME, TOKEN_SYMBOL);

            assertEq(tokenGenerator.getTotalTokensAmount(), i);
        }
    }

    //////////////////////////
    // getTokenAddress TEST //
    //////////////////////////
    function testShouldReturnTokenAddress() public {
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(TOKEN_OWNER);
            address newTokenAddress = tokenGenerator.createToken{value: fee}(
                TOKEN_NAME,
                TOKEN_SYMBOL
            );

            assertEq(tokenGenerator.getTokenAddress(i), newTokenAddress);
        }
    }

    ////////////////////////////////////////
    // getBuyerTokenAmountPurchased TESTs //
    ////////////////////////////////////////
    function testShouldReturnBuyersTokenAmountPurchased() public {
        // token #1
        address token1 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL
        );

        assertEq(tokenGenerator.getBuyerTokenAmountPurchased(token1, BUYER), 0);

        uint256 newStage = tokenGenerator.calculateNewStage(
            token1,
            TOKEN_AMOUNT_ONE
        );

        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            token1,
            TOKEN_AMOUNT_ONE,
            newStage
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(
            token1,
            TOKEN_AMOUNT_ONE
        );

        assertEq(
            tokenGenerator.getBuyerTokenAmountPurchased(token1, BUYER),
            TOKEN_AMOUNT_ONE
        );

        // token #2
        address token2 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL
        );

        assertEq(tokenGenerator.getBuyerTokenAmountPurchased(token2, BUYER), 0);

        uint256 newStage2 = tokenGenerator.calculateNewStage(
            token2,
            TOKEN_AMOUNT_TWO
        );

        uint256 totalPrice2 = tokenGenerator.calculatePurchaseCost(
            token2,
            TOKEN_AMOUNT_TWO,
            newStage2
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice2}(
            token2,
            TOKEN_AMOUNT_TWO
        );

        assertEq(
            tokenGenerator.getBuyerTokenAmountPurchased(token2, BUYER),
            TOKEN_AMOUNT_TWO
        );
    }

    /////////////////////////////////
    // getBuyerEthAmountSpent TEST //
    /////////////////////////////////
    function testShouldReturnBuyerEthAmountSpent() public {
        // token #1
        address token1 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL
        );

        assertEq(tokenGenerator.getBuyerEthAmountSpent(token1, BUYER), 0);

        uint256 newStage = tokenGenerator.calculateNewStage(
            token1,
            TOKEN_AMOUNT_ONE
        );

        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            token1,
            TOKEN_AMOUNT_ONE,
            newStage
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(
            token1,
            TOKEN_AMOUNT_ONE
        );

        assertEq(
            tokenGenerator.getBuyerEthAmountSpent(token1, BUYER),
            totalPrice
        );

        // token #2
        address token2 = tokenGenerator.createToken{value: fee}(
            TOKEN_NAME,
            TOKEN_SYMBOL
        );

        assertEq(tokenGenerator.getBuyerEthAmountSpent(token2, BUYER), 0);

        uint256 newStage2 = tokenGenerator.calculateNewStage(
            token2,
            TOKEN_AMOUNT_TWO
        );

        uint256 totalPrice2 = tokenGenerator.calculatePurchaseCost(
            token2,
            TOKEN_AMOUNT_TWO,
            newStage2
        );

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice2}(
            token2,
            TOKEN_AMOUNT_TWO
        );

        assertEq(
            tokenGenerator.getBuyerEthAmountSpent(token2, BUYER),
            totalPrice2
        );

        vm.warp(block.timestamp + (icoDeadlineInDays * ONE_DAY_IN_SECONDS) + 1);
        vm.roll(block.number + 1);

        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(token1);
        vm.prank(BUYER);
        tokenGenerator.withdrawFailedLaunchFunds(token2);

        assertEq(tokenGenerator.getBuyerEthAmountSpent(token1, BUYER), 0);
        assertEq(tokenGenerator.getBuyerEthAmountSpent(token2, BUYER), 0);
    }

    /////////////////////////
    // getCreationFee TEST //
    /////////////////////////
    function testShouldReturnTokenCreationFee() public {
        createToken();

        assertEq(tokenGenerator.getCreationFee(), fee);
    }

    //////////////////////////
    // getOwnerAddress TEST //
    //////////////////////////
    function testShouldReturnOwnerAddress() public {
        createToken();

        address expectedAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

        assertEq(tokenGenerator.getOwnerAddress(), expectedAddress);
    }

    ///////////////////////////////
    // getIcoDeadlineInDays TEST //
    ///////////////////////////////
    function testShouldReturnIcoDeadline() public {
        createToken();

        uint256 expectedDeadline = 30;

        assertEq(tokenGenerator.getIcoDeadlineInDays(), expectedDeadline);
    }

    ///////////////////////////
    // getInitialSupply TEST //
    ///////////////////////////
    function testShouldReturnInitialSupply() public {
        createToken();

        assertEq(tokenGenerator.getInitialSupply(), INITIAL_TOKEN_SUPPLY);
        assertEq(
            tokenGenerator.getInitialSupply(),
            Token(tokenAddress).balanceOf(address(tokenGenerator))
        );
    }

    ///////////////////////
    // getMaxSupply TEST //
    ///////////////////////
    function testShouldReturnMaxSupply() public {
        createToken();

        uint256 expectedMaxSupply = 1000000;

        assertEq(tokenGenerator.getMaxSupply(), expectedMaxSupply);
    }

    //////////////////////
    // getFundGoal TEST //
    //////////////////////
    function testShouldReturnFundGoal() public {
        createToken();

        assertEq(tokenGenerator.getFundGoal(), TOKEN_FUND_GOAL);
    }

    /////////////////////////////
    // getTradeableSupply TEST //
    /////////////////////////////
    function testShouldReturnTradeableSupply() public {
        createToken();

        uint256 expectedTradeableSupply = 800000;

        assertEq(tokenGenerator.getTradeableSupply(), expectedTradeableSupply);
    }

    // *************************** Gas tests *************************** //

    // *** purchaseToken *** //
    function testCheckGasCostWithPurchaseAndCreatePairAddLiqudityBurnTokens()
        public
    {
        createToken();

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            800000
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            800000,
            newStage
        );

        uint256 gasStart = gasleft();

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(tokenAddress, 800000);

        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // with createPoolAndAddLiquidityAndBurnLPTokens call:      2 937 215
        // without createPoolAndAddLiquidityAndBurnLPTokens call:     159 777
    }

    function testCheckGasPurchase() public {
        createToken();

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            800000
        );
        uint256 totalPrice = tokenGenerator.calculatePurchaseCost(
            tokenAddress,
            800000,
            newStage
        );

        uint256 gasStart = gasleft();

        vm.prank(BUYER);
        tokenGenerator.purchaseToken{value: totalPrice}(tokenAddress, 800000);

        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // with storage writes:                                                        159 777
        // with cached storage:                                                        159 132
        // with cached storage + updated validate function:                            158 664
        // with cached storage + updated validate function + optimized struct packing: 138 998
    }

    // *** calculatePurchaseCost *** //
    function testGasCalculatePurchaseCost() public {
        createToken();

        uint256 newStage = tokenGenerator.calculateNewStage(
            tokenAddress,
            800000
        );

        uint256 gasStart = gasleft();

        tokenGenerator.calculatePurchaseCost(tokenAddress, 800000, newStage);

        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // with storage writes:             51 367
        // with chached storage pointer:    51 231
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

    // *** calculateNewStage *** //
    function testGasNewStage() public {
        createToken();

        uint256 gasStart = gasleft();
        tokenGenerator.calculateNewStage(tokenAddress, 150000);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // 22780 gas - Using tokenStageSupply memory array
        // 7200 gas - Reading directly from s_tokenStageSupply
    }

    // *** createPoolAndAddLiquidityAndBurnLPTokens *** //
    function testGasCreatePairAddLiqudityBurnTokens() public {
        if (!isMainnetFork()) {
            console.log(
                "*** Test skipped on Anvil (EVM Revert on Anvil, works on fork) ***"
            );
            vm.skip(true);
        }
        createTokenAndMaxPurchase();

        uint256 gasStart = gasleft();

        tokenGenerator.createPoolAndAddLiquidityAndBurnLPTokens(tokenAddress);

        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used:", gasUsed);
        // with storage writes:             2 759 664
        // with chached storage pointer:    2 759 500
    }
}

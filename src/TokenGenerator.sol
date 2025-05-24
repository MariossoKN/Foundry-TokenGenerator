// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Token} from "./Token.sol";

import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title TokenGenerator (PumpDotFun inspired)
 * @author Mariosso
 * @notice
 * @dev
 */

contract TokenGenerator {
    // Errors
    error TokenGenerator__OnlyOwnerCanWithdraw();
    error TokenGenerator__InsufficientPayment(uint256);
    error TokenGenerator__InvalidTokenAmount();
    error TokenGenerator__InvalidTokenAddress();
    error TokenGenerator__ExceedsMaxSupply();
    error TokenGenerator__ICODeadlineExpired();
    error TokenGenerator__TokenICOActive();
    error TokenGenerator__TokenSaleActive();
    error TokenGenerator__InvalidStageCalculation();
    error TokenGenerator__ZeroAddressNotAllowed();

    // Events
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

    event BuyerFundsWithdrawed(
        address indexed tokenAddress,
        address indexed callerAddres,
        uint256 indexed ethAmountWithdrawed
    );

    event OwnerAddressChanged(
        address indexed previousOwner,
        address indexed newOwner
    );

    // Modifiers
    modifier onlyContractOwner() {
        if (msg.sender != s_owner) {
            revert TokenGenerator__OnlyOwnerCanWithdraw();
        }
        _;
    }

    // Storage variables
    uint256 private immutable i_fee;
    uint256 private immutable i_icoDeadlineInDays;

    address private s_owner;
    address[] private s_tokens;
    uint256[] private s_tokenStageSupply = [
        200000, //  Stage 0: 0    - 200k tokens (0.6  ETH total cost)
        400000, //  Stage 1: 200k - 400k tokens (0.9  ETH total cost)
        500000, //  Stage 2: 400k - 500k tokens (0.75 ETH total cost)
        550000, //  Stage 3: 500k - 550k tokens (1    ETH total cost)
        600000, //  Stage 4: 550k - 600k tokens (1.75 ETH total cost)
        650000, //  Stage 5: 600k - 650k tokens (2.75 ETH total cost)
        700000, //  Stage 6: 650k - 700k tokens (3.75 ETH total cost)
        800000 //   Stage 7: 700k - 800k tokens (9.5  ETH total cost)
    ];
    uint256[] private s_tokenStagePrice = [
        3000000000000, //   0.000003  ETH per token
        4500000000000, //   0.0000045 ETH per token
        7500000000000, //   0.0000075 ETH per token
        20000000000000, //  0.00002   ETH per token
        35000000000000, //  0.000035  ETH per token
        55000000000000, //  0.000055  ETH per token
        75000000000000, //  0.000075  ETH per token
        95000000000000 //   0.000095  ETH per token
    ];

    mapping(address tokenAddress => TokenData tokenData) private s_tokenData;
    mapping(address tokenAddress => mapping(address buyerAddress => BuyerData buyerData))
        private s_buyerData;

    uint256 private constant MAX_SUPPLY = 1e6;
    uint256 private constant INITIAL_SUPPLY = 2e5;
    uint256 private constant TRADEABLE_SUPPLY = 8e5;
    uint256 private constant FUNDING_GOAL = 21 ether;

    struct TokenData {
        uint256 tokenAmountMinted;
        uint256 tokenStage;
        uint256 tokenCreationTimestamp;
        bool tokenICOActive;
    }

    struct BuyerData {
        uint256 tokenAmountBought;
        uint256 amountEthSpent;
    }

    /**
     * @notice Initializes the TokenGenerator contract
     * @param _fee The fee required to create a new token (in wei)
     * @param _icoDeadlineInDays The deadline for ICO in days after token creation
     * @dev Sets the contract owner to the deployer and stores immutable parameters
     */
    constructor(uint256 _fee, uint256 _icoDeadlineInDays) {
        i_fee = _fee;
        i_icoDeadlineInDays = _icoDeadlineInDays;
        s_owner = msg.sender;
    }

    /**
     * @notice Creates a new token with tiered pricing mechanism
     * @param _name The name of the token to be created
     * @param _symbol The symbol of the token to be created
     * @return _tokenAddress The address of the newly created token contract
     * @dev Requires payment of creation fee, deploys new Token contract, and initializes token data
     */
    function createToken(
        string memory _name,
        string memory _symbol
    ) external payable returns (address _tokenAddress) {
        if (msg.value < i_fee) {
            revert TokenGenerator__InsufficientPayment(i_fee);
        }

        Token newToken = new Token(_name, _symbol, INITIAL_SUPPLY, msg.sender);
        address tokenAddress = address(newToken);

        s_tokens.push(tokenAddress);
        s_tokenData[tokenAddress] = TokenData({
            tokenAmountMinted: 0,
            tokenStage: 0,
            tokenCreationTimestamp: block.timestamp,
            tokenICOActive: false
        });

        emit TokenCreated(address(newToken), INITIAL_SUPPLY, msg.sender);
        return tokenAddress;
    }

    /**
     * @notice Allows users to purchase tokens at current stage pricing
     * @param _tokenAddress The address of the token to purchase
     * @param _tokenAmount The amount of tokens to purchase
     * @dev Validates purchase constraints, calculates tiered pricing, updates token stage,
     *      and forwards ETH to token contract for minting
     */
    function purchaseToken(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external payable {
        _validatePurchase(_tokenAddress, _tokenAmount);
        // check new stage and calculate price
        uint256 newStage = calculateNewStage(_tokenAddress, _tokenAmount);
        uint256 totalCost = calculatePurchaseCost(
            _tokenAddress,
            _tokenAmount,
            newStage
        );
        if (msg.value != totalCost) {
            revert TokenGenerator__InsufficientPayment(totalCost);
        }
        // update token/buyer data
        s_tokenData[_tokenAddress].tokenStage = newStage;
        s_tokenData[_tokenAddress].tokenAmountMinted += _tokenAmount;
        s_buyerData[_tokenAddress][msg.sender]
            .tokenAmountBought += _tokenAmount;
        s_buyerData[_tokenAddress][msg.sender].amountEthSpent += msg.value;
        // if max supply is sold, set ICO status to true
        if (
            getCurrentSupplyWithoutInitialSupply(_tokenAddress) ==
            TRADEABLE_SUPPLY
        ) {
            s_tokenData[_tokenAddress].tokenICOActive = true;
        }
        // send ETH to token contract and mint NFTs to token contract
        Token token = Token(_tokenAddress);
        token.buy{value: msg.value}(_tokenAddress, _tokenAmount);

        emit TokenPurchase(_tokenAddress, _tokenAmount, msg.sender, msg.value);
    }

    /**
     * @notice Calculates the total price for purchasing a specified amount of tokens
     * @param _tokenAddress The address of the token being purchased
     * @param _tokenAmount The amount of tokens to purchase
     * @param _newStage The stage the token will reach after this purchase
     * @return totalCost The total price in wei for the token purchase
     * @dev Accounts for tier-based pricing across multiple stages, calculating cost
     *      for each stage the purchase spans through
     */
    function calculatePurchaseCost(
        address _tokenAddress,
        uint256 _tokenAmount,
        uint256 _newStage
    ) public view returns (uint256 totalCost) {
        uint256 currentStage = getCurrentPricingStage(_tokenAddress);

        if (_newStage < currentStage || _newStage > 7) {
            revert TokenGenerator__InvalidStageCalculation();
        }

        uint256 tokenCurrentSupply = getCurrentSupplyWithoutInitialSupply(
            _tokenAddress
        );
        uint256 remainingTokens = _tokenAmount;
        // current supply = 120000
        // current stage = 0
        // we are buying = 235000
        // new stage = 1

        // i = 0 ; i <= 1 True
        // i = 1 ; i <= 1 True
        for (uint256 i = currentStage; i <= _newStage; ) {
            uint256 stageSupplyLimit = s_tokenStageSupply[i];
            // 200000
            // 200000
            uint256 availableInStage = stageSupplyLimit - tokenCurrentSupply;
            // 80000 = 200000 - 120000
            // 200000 = 400000 - 200000

            if (remainingTokens <= availableInStage) {
                // 235000 <= 80000
                // 155000 <= 200000
                totalCost += s_tokenStagePrice[i] * remainingTokens;
                // 0.24 + (0,0000045 * 155000) = 0,9375
                return totalCost;
            } else {
                totalCost += s_tokenStagePrice[i] * availableInStage;
                // 0.24 = 0,000003 * 80000
                tokenCurrentSupply = stageSupplyLimit;
                // 200000
                remainingTokens -= availableInStage;
                // 235000 - 80000 = 155000
            }

            ++i;
        }
        // This should never be reached with proper input validation
        return totalCost;
    }

    /**
     * @notice Determines which pricing stage a token will reach after a purchase
     * @param _tokenAddress The address of the token being purchased
     * @param _tokenAmount The amount of tokens being purchased
     * @return newStage The stage number (0-7) the token will reach after the purchase
     * @dev Iterates through stages to find where the new supply total will land
     */
    function calculateNewStage(
        address _tokenAddress,
        uint256 _tokenAmount
    ) public view returns (uint256 newStage) {
        uint256 currentStage = getCurrentPricingStage(_tokenAddress);
        uint256 newTokenSupply = getCurrentSupplyWithoutInitialSupply(
            _tokenAddress
        ) + _tokenAmount;
        if (newTokenSupply == TRADEABLE_SUPPLY) {
            return 7;
        }
        for (uint256 i = currentStage; i < 8; i++) {
            if (s_tokenStageSupply[i] > newTokenSupply) {
                return i;
            }
        }
        // This should never be reached with proper input validation
        return 7;
    }

    /**
     * @notice Allows buyers to withdraw their ETH if ICO fails or deadline is reached
     * @param _tokenAddress The address of the token to withdraw funds from
     * @dev Only callable after ICO deadline and if ICO hasn't succeeded,
     *      resets buyer's spent amount and calls token contract to transfer ETH
     */
    function withdrawFailedLaunchFunds(address _tokenAddress) external payable {
        if (!isTokenDeadlineExpired(_tokenAddress)) {
            revert TokenGenerator__TokenSaleActive();
        }
        if (getTokenICOStatus(_tokenAddress)) {
            revert TokenGenerator__TokenICOActive();
        }
        uint256 amountToWithdraw = s_buyerData[_tokenAddress][msg.sender]
            .amountEthSpent;

        s_buyerData[_tokenAddress][msg.sender].amountEthSpent = 0;

        Token(_tokenAddress).withdrawBuyerFunds(msg.sender, amountToWithdraw);
        emit BuyerFundsWithdrawed(
            address(_tokenAddress),
            msg.sender,
            amountToWithdraw
        );
    }

    /**
     * @notice Allows contract owner to withdraw accumulated fees
     * @dev Only callable by contract owner, transfers entire contract balance to owner
     */
    function withdrawAccumulatedFees() external onlyContractOwner {
        (bool success, ) = (s_owner).call{value: address(this).balance}("");
        require(success, "Fee withdrawal failed");
    }

    /**
     * @notice Allows current owner to transfer ownership to a new address
     * @param _newOwner The address of the new contract owner
     * @dev Only callable by current owner, validates new address is not zero address
     */
    function transferOwnership(address _newOwner) external onlyContractOwner {
        if (_newOwner == address(0)) {
            revert TokenGenerator__ZeroAddressNotAllowed();
        }
        address previousOwner = s_owner;
        s_owner = _newOwner;

        emit OwnerAddressChanged(previousOwner, _newOwner);
    }

    /**
     * @notice Validate purchase parameters
     * @param _tokenAddress The token being purchased
     * @param _tokenAmount Amount being purchased
     */
    function _validatePurchase(
        address _tokenAddress,
        uint256 _tokenAmount
    ) internal view {
        if (
            getCurrentSupplyWithoutInitialSupply(_tokenAddress) + _tokenAmount >
            TRADEABLE_SUPPLY
        ) {
            revert TokenGenerator__ExceedsMaxSupply();
        }
        if (_tokenAddress == address(0)) {
            revert TokenGenerator__ZeroAddressNotAllowed();
        }
        if (getTokenICOStatus(_tokenAddress)) {
            revert TokenGenerator__TokenICOActive();
        }
        if (getTokenCreationTimestamp(_tokenAddress) == 0) {
            revert TokenGenerator__InvalidTokenAddress();
        }
        if (_tokenAmount == 0) {
            revert TokenGenerator__InvalidTokenAmount();
        }

        if (isTokenDeadlineExpired(_tokenAddress)) {
            revert TokenGenerator__ICODeadlineExpired();
        }
    }

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////
    function getCurrentSupplyWithoutInitialSupply(
        address tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[tokenAddress].tokenAmountMinted;
    }

    function getElapsedTimeSinceCreation(
        address _tokenAddress
    ) public view returns (uint256) {
        return (block.timestamp -
            s_tokenData[_tokenAddress].tokenCreationTimestamp);
    }

    function getTokenCreationTimestamp(
        address _tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[_tokenAddress].tokenCreationTimestamp;
    }

    function getTokenICOStatus(address _address) public view returns (bool) {
        return s_tokenData[_address].tokenICOActive;
    }

    function getCurrentPricingStage(
        address tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[tokenAddress].tokenStage;
    }

    function isTokenDeadlineExpired(
        address _tokenAddress
    ) public view returns (bool) {
        return
            getElapsedTimeSinceCreation(_tokenAddress) >
            (i_icoDeadlineInDays * 1 days);
    }

    /////////////////////////////
    // EXTERNAL VIEW FUNCTIONS //
    /////////////////////////////
    function getStagePrice(uint256 _stage) external view returns (uint256) {
        return s_tokenStagePrice[_stage];
    }

    function getStageSupply(uint256 _stage) external view returns (uint256) {
        return s_tokenStageSupply[_stage];
    }

    function getTokenCreator(
        address _tokenAddress
    ) external view returns (address) {
        return Token(_tokenAddress).getTokenCreator();
    }

    function getTokenCurrentStageSupply(
        address tokenAddress
    ) external view returns (uint256) {
        uint256 tokenStage = getCurrentPricingStage(tokenAddress);
        return s_tokenStageSupply[tokenStage];
    }

    function getTokenCurrentStagePrice(
        address tokenAddress
    ) external view returns (uint256) {
        uint256 tokenStage = getCurrentPricingStage(tokenAddress);
        return s_tokenStagePrice[tokenStage];
    }

    function getRemainingSupplyInCurrentStage(
        address tokenAddress
    ) external view returns (uint256) {
        uint256 stage = getCurrentPricingStage(tokenAddress);
        uint256 currentSupply = getCurrentSupplyWithoutInitialSupply(
            tokenAddress
        );
        return s_tokenStageSupply[stage] - currentSupply;
    }

    function getTotalTokensAmount() external view returns (uint256) {
        return s_tokens.length;
    }

    function getTokenAddress(uint256 _tokenId) external view returns (address) {
        return s_tokens[_tokenId];
    }

    function getAvailableStageSupply(
        address tokenAddress
    ) external view returns (uint256) {
        uint256 tokenStage = getCurrentPricingStage(tokenAddress);
        uint256 currentSupply = getCurrentSupplyWithoutInitialSupply(
            tokenAddress
        );
        return s_tokenStageSupply[tokenStage] - currentSupply;
    }

    function getBuyerTokenAmountPurchased(
        address _tokenAddress,
        address _buyerAddress
    ) external view returns (uint256) {
        return s_buyerData[_tokenAddress][_buyerAddress].tokenAmountBought;
    }

    function getBuyerEthAmountSpent(
        address _tokenAddress,
        address _buyerAddress
    ) external view returns (uint256) {
        return s_buyerData[_tokenAddress][_buyerAddress].amountEthSpent;
    }

    function getCreationFees() external view returns (uint256) {
        return i_fee;
    }

    function getOwnerAddress() external view returns (address) {
        return s_owner;
    }

    function getIcoDeadlineInDays() external view returns (uint256) {
        return i_icoDeadlineInDays;
    }

    ///////////////////////////
    // EXTERNAL PURE FUNCTIONS //
    ///////////////////////////

    function getInitialSupply() external pure returns (uint256) {
        return INITIAL_SUPPLY;
    }

    function getMaxSupply() external pure returns (uint256) {
        return MAX_SUPPLY;
    }

    function getFundGoal() external pure returns (uint256) {
        return FUNDING_GOAL;
    }

    function getTradeableSupply() external pure returns (uint256) {
        return TRADEABLE_SUPPLY;
    }

    //////////////////////
    // FALLBACK RECEIVE //
    //////////////////////

    fallback() external payable {}

    receive() external payable {}
}

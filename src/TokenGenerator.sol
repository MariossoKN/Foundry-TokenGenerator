// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Token} from "./Token.sol";

import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/**
 * @title TokenGenerator (PumpDotFun inspired)
 * @author Mariosso
 * @notice
 * @dev
 */

contract TokenGenerator {
    ////////////
    // Errors //
    ////////////
    error TokenGenerator__OnlyOwner();
    error TokenGenerator__InsufficientPayment(uint256);
    error TokenGenerator__InvalidTokenAmount();
    error TokenGenerator__InvalidTokenAddress();
    error TokenGenerator__ExceedsMaxSupply();
    error TokenGenerator__ICODeadlineExpired();
    error TokenGenerator__TokenICOActive();
    error TokenGenerator__TokenICONotActive();
    error TokenGenerator__TokenSaleActive();
    error TokenGenerator__InvalidStageCalculation();
    error TokenGenerator__ZeroAddressNotAllowed();
    error TokenGenerator__NoEthToWithdraw();
    error TokenGenerator__FundingGoalNotMet();
    error TokenGenerator__FundingNotComplete();
    error TokenGenerator__TokenFundingComplete();
    error TokenGenerator__NoTokensLeft();

    ////////////
    // Events //
    ////////////
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

    event OwnerAddressChanged(
        address indexed previousOwner,
        address indexed newOwner
    );

    event FeesWithdrawed(address owner, uint256 ethAmount);

    event PoolCreatedliquidityAddedLPTokensBurned(
        address tokenAddress,
        address poolAddress,
        uint256 liquidityBurnt
    );

    event TokensClaimed(
        address tokenAddress,
        address buyerAddress,
        uint256 tokenAmountClaimed
    );

    ///////////////
    // Modifiers //
    ///////////////
    modifier onlyContractOwner() {
        if (msg.sender != s_owner) {
            revert TokenGenerator__OnlyOwner();
        }
        _;
    }

    modifier cantBeZeroAddress(address _inputAddress) {
        if (_inputAddress == address(0)) {
            revert TokenGenerator__ZeroAddressNotAllowed();
        }
        _;
    }

    ///////////////////////
    // Storage variables //
    ///////////////////////
    uint256 private immutable i_fee;
    uint256 private immutable i_icoDeadlineInDays;

    IUniswapV2Factory private immutable i_uniswapV2Factory;
    IUniswapV2Router02 private immutable i_uniswapV2Router;

    address private s_owner;
    address[] private s_tokens;
    uint256 private s_accumulatedFees;
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
        uint256 amountMinted;
        uint256 ethFunded;
        uint256 creationTimestamp;
        uint8 stage;
        bool icoActive;
        bool fundingComplete;
    }

    struct BuyerData {
        uint256 tokenAmountPurchased;
        uint256 amountEthSpent;
    }

    /**
     * @notice Initializes the TokenGenerator contract
     * @param _fee The fee required to create a new token (in wei)
     * @param _icoDeadlineInDays The deadline for ICO in days after token creation
     * @dev Sets the contract owner to the deployer and stores immutable parameters
     */
    constructor(
        uint256 _fee,
        uint256 _icoDeadlineInDays,
        address _uniswapV2FactoryAddress,
        address _uniswapV2RouterAddress
    )
        cantBeZeroAddress(_uniswapV2FactoryAddress)
        cantBeZeroAddress(_uniswapV2RouterAddress)
    {
        i_fee = _fee;
        i_icoDeadlineInDays = _icoDeadlineInDays;
        s_owner = msg.sender;
        i_uniswapV2Factory = IUniswapV2Factory(_uniswapV2FactoryAddress);
        i_uniswapV2Router = IUniswapV2Router02(_uniswapV2RouterAddress);
    }

    //////////////////////
    // FALLBACK RECEIVE //
    //////////////////////
    receive() external payable {
        revert("ETH not accepted");
    }

    fallback() external payable {
        revert("ETH not accepted");
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
            amountMinted: 0,
            stage: 0,
            creationTimestamp: block.timestamp,
            ethFunded: 0,
            icoActive: false,
            fundingComplete: false
        });

        s_accumulatedFees += msg.value;

        emit TokenCreated(tokenAddress, INITIAL_SUPPLY, msg.sender);
        return tokenAddress;
    }

    /**
     * @notice Allows users to purchase tokens at current stage pricing
     * @param _tokenAddress The address of the token to purchase
     * @param _tokenAmount The amount of tokens to purchase
     * @dev Validates purchase constraints, calculates tiered pricing, updates token stage,
     *      forwards ETH and mints tokens to this contract
     */
    function purchaseToken(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external payable {
        _validatePurchase(_tokenAddress, _tokenAmount);

        uint8 newStage = calculateNewStage(_tokenAddress, _tokenAmount);
        uint256 totalCost = calculatePurchaseCost(
            _tokenAddress,
            _tokenAmount,
            newStage
        );
        if (msg.value != totalCost) {
            revert TokenGenerator__InsufficientPayment(totalCost);
        }

        TokenData storage tokenData = s_tokenData[_tokenAddress];
        BuyerData storage buyerData = s_buyerData[_tokenAddress][msg.sender];

        tokenData.stage = newStage;
        tokenData.amountMinted += _tokenAmount;
        tokenData.ethFunded += msg.value;

        buyerData.tokenAmountPurchased += _tokenAmount;
        buyerData.amountEthSpent += msg.value;

        if (tokenData.amountMinted == TRADEABLE_SUPPLY) {
            tokenData.fundingComplete = true;
        }

        Token(_tokenAddress).mint(_tokenAmount);

        emit TokenPurchase(
            _tokenAddress,
            _tokenAmount,
            msg.sender,
            msg.value,
            tokenData.fundingComplete
        );
    }

    /**
     * @notice Creates a Uniswap V2 pool, adds liquidity, and burns LP tokens for a successfully funded token
     * @param _tokenAddress The address of the token to create pool and add liquidity for
     * @return poolAddress The address of the created or existing Uniswap V2 pair
     * @return liquidity The amount of LP tokens that were burned
     * @dev This function should be called separately from purchaseToken to avoid high gas costs for the last buyer.
     *      !!! Should be called by Chainlink Automation or by an incentive mechanism for external callers !!!
     *      Requirements:
     *      - Token funding must be complete (800k tokens sold)
     *      - ICO must not already be active
     *      - Funding goal of 21 ETH must be met
     *      The function:
     *      1. Validates ICO conditions
     *      2. Creates or gets existing Uniswap V2 pair
     *      3. Approves router to spend initial supply tokens
     *      4. Adds liquidity with initial supply tokens and collected ETH
     *      5. Burns all received LP tokens by sending them to address(0)
     *      6. Sets ICO as active and resets ethFunded to 0
     */
    function createPoolAndAddLiquidityAndBurnLPTokens(
        address _tokenAddress
    ) external returns (address poolAddress, uint256 liquidity) {
        _validateICO(_tokenAddress);

        TokenData storage tokenData = s_tokenData[_tokenAddress];
        uint256 ethFunded = tokenData.ethFunded;
        tokenData.ethFunded = 0;
        tokenData.icoActive = true;

        // check/create pool
        address weth = IUniswapV2Router02(i_uniswapV2Router).WETH();
        poolAddress = i_uniswapV2Factory.getPair(_tokenAddress, weth);

        if (poolAddress == address(0)) {
            poolAddress = i_uniswapV2Factory.createPair(_tokenAddress, weth);
        }

        Token(_tokenAddress).approve(
            address(i_uniswapV2Router),
            INITIAL_SUPPLY
        );

        // create liquidity for the pair
        (, , liquidity) = i_uniswapV2Router.addLiquidityETH{value: ethFunded}(
            _tokenAddress,
            INITIAL_SUPPLY,
            INITIAL_SUPPLY,
            ethFunded,
            address(this),
            block.timestamp
        );

        // burn liquidity tokens
        IUniswapV2Pair pool = IUniswapV2Pair(poolAddress);
        pool.transfer(address(0), liquidity);

        emit PoolCreatedliquidityAddedLPTokensBurned(
            _tokenAddress,
            poolAddress,
            liquidity
        );
    }

    /**
     * @notice Allows buyers to withdraw their ETH if ICO fails (deadline is reached)
     * @param _tokenAddress The address of the token to withdraw funds from
     * @dev Only callable after ICO deadline,
     *      resets buyer's spent amount and transfers ETH to caller
     */
    function withdrawFailedLaunchFunds(
        address _tokenAddress
    ) external cantBeZeroAddress(_tokenAddress) {
        if (getTokenFundingComplete(_tokenAddress)) {
            revert TokenGenerator__TokenFundingComplete();
        }
        if (!isTokenDeadlineExpired(_tokenAddress)) {
            revert TokenGenerator__TokenSaleActive();
        }

        uint256 amountToWithdraw = s_buyerData[_tokenAddress][msg.sender]
            .amountEthSpent;
        if (amountToWithdraw == 0) {
            revert TokenGenerator__NoEthToWithdraw();
        }
        s_buyerData[_tokenAddress][msg.sender].amountEthSpent = 0;

        (bool success, ) = (msg.sender).call{value: amountToWithdraw}("");
        require(success, "Fund withdrawal failed");

        emit BuyerFundsWithdrawn(_tokenAddress, msg.sender, amountToWithdraw);
    }

    /**
     * @notice Allows contract owner to withdraw accumulated fees
     * @dev Only callable by contract owner, transfers accumulatedFees to owner and
     * resets accumulatedFees to zero
     */
    function withdrawAccumulatedFees() external onlyContractOwner {
        uint256 accumulatedFees = s_accumulatedFees;
        s_accumulatedFees = 0;

        (bool success, ) = (s_owner).call{value: accumulatedFees}("");
        require(success, "Fee withdrawal failed");

        emit FeesWithdrawed(s_owner, accumulatedFees);
    }

    /**
     * @notice Allows current owner to transfer ownership to a new address
     * @param _newOwner The address of the new contract owner
     * @dev Only callable by current owner, validates new address is not zero address
     */
    function transferOwnership(
        address _newOwner
    ) external onlyContractOwner cantBeZeroAddress(_newOwner) {
        address previousOwner = s_owner;
        s_owner = _newOwner;

        emit OwnerAddressChanged(previousOwner, _newOwner);
    }

    /**
     * @notice Allows buyers to claim their purchased tokens after a successful ICO
     * @param _tokenAddress The address of the token to claim
     * @dev This function can only be called after the ICO is active (pool created and liquidity added).
     *      Requirements:
     *      - Token address cannot be zero address
     *      - ICO must be active (tokens are now tradeable)
     *      - Caller must have purchased tokens during the funding phase
     *      - Caller must have unclaimed tokens remaining
     *      The function:
     *      1. Validates that ICO is active
     *      2. Retrieves buyer's purchased token amount
     *      3. Resets buyer's purchased amount to prevent double claiming
     *      4. Transfers tokens from this contract to the buyer
     * @custom:security This function prevents double claiming by resetting the buyer's purchased amount
     * @custom:gas-optimization Tokens are transferred directly without additional approvals
     */
    function claimTokens(
        address _tokenAddress
    ) external cantBeZeroAddress(_tokenAddress) {
        if (!s_tokenData[_tokenAddress].icoActive) {
            revert TokenGenerator__TokenICONotActive();
        }
        uint256 tokenAmountPurchased = s_buyerData[_tokenAddress][msg.sender]
            .tokenAmountPurchased;
        if (tokenAmountPurchased == 0) {
            revert TokenGenerator__NoTokensLeft();
        }

        s_buyerData[_tokenAddress][msg.sender].tokenAmountPurchased = 0;

        Token(_tokenAddress).transfer(msg.sender, tokenAmountPurchased);

        emit TokensClaimed(_tokenAddress, msg.sender, tokenAmountPurchased);
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
    ) public view returns (uint8 newStage) {
        uint8 currentStage = getCurrentPricingStage(_tokenAddress);
        uint256 newTokenSupply = getCurrentSupplyWithoutInitialSupply(
            _tokenAddress
        ) + _tokenAmount;
        if (newTokenSupply == TRADEABLE_SUPPLY) {
            return 7;
        }
        for (uint8 i = currentStage; i < 8; i++) {
            if (s_tokenStageSupply[i] > newTokenSupply) {
                return i;
            }
        }
        // This should never be reached with proper input validation
        return 7;
    }

    /**
     * @notice Calculates the total price for purchasing a specified amount of tokens
     * @param _tokenAddress The address of the token being purchased
     * @param _tokenAmount The amount of tokens to purchase
     * @param _newStage The stage (tier) the token will reach after this purchase
     * @return totalCost The total price in wei for the token purchase
     * @dev Accounts for tier-based pricing across multiple stages, calculating cost
     *      for each stage the purchase spans through
     */
    function calculatePurchaseCost(
        address _tokenAddress,
        uint256 _tokenAmount,
        uint256 _newStage
    ) public view returns (uint256 totalCost) {
        TokenData storage tokenData = s_tokenData[_tokenAddress];
        uint256 currentStage = tokenData.stage;

        if (_newStage < currentStage || _newStage > 7) {
            revert TokenGenerator__InvalidStageCalculation();
        }

        uint256 tokenCurrentSupply = tokenData.amountMinted;
        uint256 remainingTokens = _tokenAmount;

        uint256[] storage stageSupply = s_tokenStageSupply;
        uint256[] storage stagePrices = s_tokenStagePrice;

        for (uint256 i = currentStage; i <= _newStage; ) {
            uint256 stageSupplyLimit = stageSupply[i];
            uint256 availableInStage = stageSupplyLimit - tokenCurrentSupply;

            if (remainingTokens <= availableInStage) {
                totalCost += stagePrices[i] * remainingTokens;
                return totalCost;
            } else {
                totalCost += stagePrices[i] * availableInStage;
                tokenCurrentSupply = stageSupplyLimit;
                remainingTokens -= availableInStage;
            }
            ++i;
        }
        return totalCost;
    }

    /**
     * @notice Validate purchase parameters
     * @param _tokenAddress The token being purchased
     * @param _tokenAmount Amount being purchased
     * @dev Validates that:
     *  1) provided token address is not address zero,
     *  2) the token amount doesnt exceed tradeable supply,
     *  3) the provided token address exists,
     *  4) token amount is not zero,
     *  5) deadline not expired.
     */
    function _validatePurchase(
        address _tokenAddress,
        uint256 _tokenAmount
    ) internal view cantBeZeroAddress(_tokenAddress) {
        TokenData storage tokenData = s_tokenData[_tokenAddress];

        if (tokenData.amountMinted + _tokenAmount > TRADEABLE_SUPPLY) {
            revert TokenGenerator__ExceedsMaxSupply();
        }
        if (tokenData.creationTimestamp == 0) {
            revert TokenGenerator__InvalidTokenAddress();
        }
        if (_tokenAmount == 0) {
            revert TokenGenerator__InvalidTokenAmount();
        }
        if (
            block.timestamp >
            tokenData.creationTimestamp + (i_icoDeadlineInDays * 1 days)
        ) {
            revert TokenGenerator__ICODeadlineExpired();
        }
    }

    /**
     * @notice Validates that a token meets all requirements for ICO activation (pool creation)
     * @param _tokenAddress The address of the token to validate for ICO
     * @dev This is an internal function used by createPoolAndAddLiquidityAndBurnLPTokens.
     *      Validation checks performed:
     *      1. Token address is not zero address (enforced by modifier)
     *      2. Token funding is complete (800k tokens sold)
     *      3. ICO is not already active (prevents double activation)
     *      4. Funding goal of exactly 21 ETH has been met
     *
     *      Reverts with specific errors:
     *      - TokenGenerator__FundingNotComplete: If less than 800k tokens sold
     *      - TokenGenerator__TokenICOActive: If ICO already activated
     *      - TokenGenerator__FundingGoalNotMet: If ETH raised ≠ 21 ETH
     * @custom:security Prevents multiple pool creations and ensures exact funding requirements
     */
    function _validateICO(
        address _tokenAddress
    ) internal view cantBeZeroAddress(_tokenAddress) {
        if (!s_tokenData[_tokenAddress].fundingComplete) {
            revert TokenGenerator__FundingNotComplete();
        }
        if (s_tokenData[_tokenAddress].icoActive) {
            revert TokenGenerator__TokenICOActive();
        }
        if (getTokenEthAmountFunded(_tokenAddress) != FUNDING_GOAL) {
            revert TokenGenerator__FundingGoalNotMet();
        }
    }

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////
    function getCurrentSupplyWithoutInitialSupply(
        address tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[tokenAddress].amountMinted;
    }

    function getElapsedTimeSinceCreation(
        address _tokenAddress
    ) public view returns (uint256) {
        return (block.timestamp - s_tokenData[_tokenAddress].creationTimestamp);
    }

    function getCurrentPricingStage(
        address tokenAddress
    ) public view returns (uint8) {
        return s_tokenData[tokenAddress].stage;
    }

    function isTokenDeadlineExpired(
        address _tokenAddress
    ) public view returns (bool) {
        return
            getElapsedTimeSinceCreation(_tokenAddress) >
            (i_icoDeadlineInDays * 1 days);
    }

    function getTokenEthAmountFunded(
        address _tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[_tokenAddress].ethFunded;
    }

    function getTokenFundingComplete(
        address _tokenAddress
    ) public view returns (bool) {
        return s_tokenData[_tokenAddress].fundingComplete;
    }

    /////////////////////////////
    // EXTERNAL VIEW FUNCTIONS //
    /////////////////////////////
    function getAccumulatedFees() external view returns (uint256) {
        return s_accumulatedFees;
    }

    function getStagePrice(uint256 _stage) external view returns (uint256) {
        return s_tokenStagePrice[_stage];
    }

    function getStageSupply(uint256 _stage) external view returns (uint256) {
        return s_tokenStageSupply[_stage];
    }

    function getTokenCreationTimestamp(
        address _tokenAddress
    ) external view returns (uint256) {
        return s_tokenData[_tokenAddress].creationTimestamp;
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

    function getAvailableStageSupply(
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

    function getBuyerTokenAmountPurchased(
        address _tokenAddress,
        address _buyerAddress
    ) external view returns (uint256) {
        return s_buyerData[_tokenAddress][_buyerAddress].tokenAmountPurchased;
    }

    function getBuyerEthAmountSpent(
        address _tokenAddress,
        address _buyerAddress
    ) external view returns (uint256) {
        return s_buyerData[_tokenAddress][_buyerAddress].amountEthSpent;
    }

    function getCreationFee() external view returns (uint256) {
        return i_fee;
    }

    function getOwnerAddress() external view returns (address) {
        return s_owner;
    }

    function getIcoDeadlineInDays() external view returns (uint256) {
        return i_icoDeadlineInDays;
    }

    function getTokenICOStatus(address _address) external view returns (bool) {
        return s_tokenData[_address].icoActive;
    }

    function getUniswapV2FactoryAddress() public view returns (address) {
        return address(i_uniswapV2Factory);
    }

    function getUniswapV2RouterAddress() public view returns (address) {
        return address(i_uniswapV2Router);
    }

    /////////////////////////////
    // EXTERNAL PURE FUNCTIONS //
    /////////////////////////////
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
}

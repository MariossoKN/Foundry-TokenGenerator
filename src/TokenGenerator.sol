// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

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
    // Events
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

    // Storage variables
    uint256 private immutable i_fee;
    address private immutable i_owner;

    uint256[] private s_tokenStageSupply = [
        200000, // 0    0 - 200000          0.6
        400000, // 1    200000 - 400000     0.9
        500000, // 2    400000 - 500000     0.75
        550000, // 3    500000 - 550000     1
        600000, // 4    550000 - 600000     1.75
        650000, // 5    600000 - 650000     2.75
        700000, // 6    650000 - 700000     3.75
        800000 // 7     700000 - 800000     9.5
    ];
    uint256[] private s_tokenStagePrice = [
        3000000000000,
        4500000000000,
        7500000000000,
        20000000000000,
        35000000000000,
        55000000000000,
        75000000000000,
        95000000000000
    ];
    address[] private s_tokens;
    uint256 private constant MAX_SUPPLY = 1000000;
    uint256 private constant INITIAL_SUPPLY = 200000; // 20% of max supply
    uint256 private constant FUND_GOAL = 21 ether;
    uint256 private constant ICO_DEADLINE_IN_DAYS = 30;

    struct TokenData {
        uint256 tokenAmountMinted;
        uint256 tokenStage;
        uint256 tokenCreationStart;
        bool tokenICOActive;
    }

    struct BuyerData {
        uint256 tokenAmountBought;
        uint256 amountEthSpent;
    }

    mapping(address tokenAddress => TokenData tokenData) private s_tokenData;
    mapping(address tokenAddress => mapping(address buyerAddress => BuyerData buyerData))
        private s_buyerData;

    // Errors
    error TokenGenerator__OnlyOwnerCanWithdraw();
    error TokenGenerator__ValueSentIsLow(uint256);
    error TokenGenerator__TokenAmountTooLow();
    error TokenGenerator__WrongTokenAddress();
    error TokenGenerator__TokenAmountExceedsStageSellLimit(uint256);
    error TokenGenerator__ICODeadlineReached();
    error TokenGenerator__TokenICOReached();
    error TokenGenerator__TokenSaleStillActive();
    error TokenGenerator__WrongStageCalculation();

    /**
     * @dev
     */
    constructor(uint256 _fee) {
        i_fee = _fee;
        i_owner = msg.sender;
    }

    /**
     * @dev
     */
    function createToken(
        string memory _name,
        string memory _symbol
    ) external payable returns (address _tokenAddress) {
        if (msg.value < i_fee) {
            revert TokenGenerator__ValueSentIsLow(i_fee);
        }

        Token newToken = new Token(_name, _symbol, INITIAL_SUPPLY, msg.sender);
        address tokenAddress = address(newToken);

        s_tokens.push(tokenAddress);
        s_tokenData[tokenAddress] = TokenData(0, 0, block.timestamp, false);

        emit TokenCreated(address(newToken), INITIAL_SUPPLY, msg.sender);
        return tokenAddress;
    }

    function checkNewStage(
        address _tokenAddress,
        uint256 _tokenAmount
    ) public view returns (uint256 newStage) {
        uint256 tokenStage = getTokenStage(_tokenAddress);
        uint256 newTokenSupply = getCurrentSupplyWithoutInitialSupply(
            _tokenAddress
        ) + _tokenAmount;
        if (newTokenSupply == 800000) {
            return 7;
        }
        for (uint256 i = tokenStage; i < 8; i++) {
            if (s_tokenStageSupply[i] > newTokenSupply) {
                return i;
            }
        }
    }

    function calculatePriceForTokens(
        address _tokenAddress,
        uint256 _tokenAmount,
        uint256 _newStage
    ) public view returns (uint256 tokensPrice) {
        uint256 startingStage = getTokenStage(_tokenAddress);

        if (_newStage < startingStage || _newStage > 7) {
            revert TokenGenerator__WrongStageCalculation();
        }
        uint256 tokenCurrentSupply = getCurrentSupplyWithoutInitialSupply(
            _tokenAddress
        );
        uint256 tokenAmountLeft = _tokenAmount;
        for (uint256 i = startingStage; i < _newStage + 1; i++) {
            if (tokenAmountLeft > getStageSupply(i) - tokenCurrentSupply) {
                uint256 currentStageSupplyLeft = getStageSupply(i) -
                    tokenCurrentSupply;
                tokensPrice += s_tokenStagePrice[i] * currentStageSupplyLeft;
                tokenCurrentSupply += currentStageSupplyLeft;
                tokenAmountLeft -= currentStageSupplyLeft;
            } else {
                tokensPrice += s_tokenStagePrice[i] * tokenAmountLeft;
                return tokensPrice;
            }
        }
        return tokensPrice;
    }

    /**
     * @notice Calculates the total price for purchasing a specified amount of tokens
     * @param _tokenAddress The address of the token being purchased
     * @param _tokenAmount The amount of tokens to purchase
     * @param _newStage The stage the token will reach after this purchase
     * @return tokensPrice The total price in wei for the token purchase
     * @dev This function accounts for tier-based pricing across multiple stages
     */
    function calculatePriceForTokens2(
        address _tokenAddress,
        uint256 _tokenAmount,
        uint256 _newStage
    ) public view returns (uint256 tokensPrice) {
        uint256 startingStage = getTokenStage(_tokenAddress);

        if (_newStage < startingStage) {
            revert TokenGenerator__WrongStageCalculation();
        }
        if (_newStage > 7) {
            revert TokenGenerator__WrongStageCalculation();
        }

        uint256 tokenCurrentSupply = getCurrentSupplyWithoutInitialSupply(
            _tokenAddress
        );
        uint256 tokenAmountLeft = _tokenAmount;

        for (uint256 i = startingStage; i <= _newStage; ) {
            uint256 stageSupplyLimit = s_tokenStageSupply[i];
            uint256 availableInStage = stageSupplyLimit - tokenCurrentSupply;

            if (tokenAmountLeft <= availableInStage) {
                // All remaining tokens fit in current stage
                tokensPrice += s_tokenStagePrice[i] * tokenAmountLeft;
                return tokensPrice;
            } else {
                // Consume entire stage and move to next
                tokensPrice += s_tokenStagePrice[i] * availableInStage;
                tokenCurrentSupply = stageSupplyLimit;
                tokenAmountLeft -= availableInStage;
            }

            ++i;
        }
        // This should never be reached with proper input validation
        return tokensPrice;
    }

    function buyToken(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external payable {
        if (_tokenAddress == address(0)) {
            revert TokenGenerator__WrongTokenAddress();
        }
        if (getTokenICOStatus(_tokenAddress) == true) {
            revert TokenGenerator__TokenICOReached();
        }
        if (
            getTokenDeadlineTimeLeft(_tokenAddress) >
            ICO_DEADLINE_IN_DAYS * 86400
        ) {
            revert TokenGenerator__ICODeadlineReached();
        }
        if (getTokenCreationTimestamp(_tokenAddress) == 0) {
            revert TokenGenerator__WrongTokenAddress();
        }
        if (_tokenAmount == 0) {
            revert TokenGenerator__TokenAmountTooLow();
        }
        uint256 newStage = checkNewStage(_tokenAddress, _tokenAmount);
        uint256 tokensPrice = calculatePriceForTokens(
            _tokenAddress,
            _tokenAmount,
            newStage
        );
        if (msg.value < tokensPrice) {
            revert TokenGenerator__ValueSentIsLow(tokensPrice);
        }

        // s_tokenData[_tokenAddress].tokenStage == newStage;
        s_tokenData[_tokenAddress].tokenAmountMinted += _tokenAmount;
        s_buyerData[_tokenAddress][msg.sender]
            .tokenAmountBought += _tokenAmount;
        s_buyerData[_tokenAddress][msg.sender].amountEthSpent += msg.value;

        if (
            getCurrentSupplyWithoutInitialSupply(_tokenAddress) ==
            (MAX_SUPPLY - INITIAL_SUPPLY)
        ) {
            s_tokenData[_tokenAddress].tokenICOActive = true;
        }

        Token token = Token(_tokenAddress);
        token.buy{value: msg.value}(_tokenAddress, _tokenAmount);

        emit TokenBuy(address(_tokenAddress), _tokenAmount, msg.sender);
    }

    function withdrawFunds(address _tokenAddress) external payable {
        if (
            ICO_DEADLINE_IN_DAYS * 86400 >
            getTokenDeadlineTimeLeft(_tokenAddress)
        ) {
            revert TokenGenerator__TokenSaleStillActive();
        }
        if (getTokenICOStatus(_tokenAddress) == true) {
            revert TokenGenerator__TokenICOReached();
        }
        uint256 amountToWithdraw = s_buyerData[_tokenAddress][msg.sender]
            .amountEthSpent;

        s_buyerData[_tokenAddress][msg.sender].amountEthSpent = 0;

        Token(_tokenAddress).withdrawBuyerFunds(msg.sender, amountToWithdraw);
    }

    function withdrawFees() external {
        if (msg.sender != i_owner) {
            revert TokenGenerator__OnlyOwnerCanWithdraw();
        }
        (bool success, ) = (i_owner).call{value: address(this).balance}("");
        require(success, "Fees withdraw failed");
    }

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////

    // function calculatePriceForTokens(
    //     address tokenAddress,
    //     uint256 tokenAmount
    // ) public view returns (uint256) {
    //     uint256 pricePerToken = getTokenCurrentStagePrice(tokenAddress);

    //     return tokenAmount * pricePerToken;
    // }

    function getCurrentSupplyWithoutInitialSupply(
        address tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[tokenAddress].tokenAmountMinted;
    }

    function getStagePrice(uint256 _stage) public view returns (uint256) {
        return s_tokenStagePrice[_stage];
    }

    function getStageSupply(uint256 _stage) public view returns (uint256) {
        return s_tokenStageSupply[_stage];
    }

    function getTokenDeadlineTimeLeft(
        address _tokenAddress
    ) public view returns (uint256) {
        return (block.timestamp -
            s_tokenData[_tokenAddress].tokenCreationStart);
    }

    function getTokenCreationTimestamp(
        address _tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[_tokenAddress].tokenCreationStart;
    }

    function getTokenICOStatus(address _address) public view returns (bool) {
        return s_tokenData[_address].tokenICOActive;
    }

    function getTokenCreatorAddress(
        address _tokenAddress
    ) public view returns (address) {
        return Token(_tokenAddress).getTokenCreator();
    }

    function getTokenCurrentStageSupply(
        address tokenAddress
    ) public view returns (uint256) {
        uint256 tokenStage = getTokenStage(tokenAddress);
        return s_tokenStageSupply[tokenStage];
    }

    function getTokenStage(address tokenAddress) public view returns (uint256) {
        return s_tokenData[tokenAddress].tokenStage;
    }

    function getTokenCurrentStagePrice(
        address tokenAddress
    ) public view returns (uint256) {
        uint256 tokenStage = getTokenStage(tokenAddress);
        return s_tokenStagePrice[tokenStage];
    }

    function getAvailableStageSupply(
        address tokenAddress
    ) public view returns (uint256) {
        uint256 tokenStage = getTokenStage(tokenAddress);
        uint256 currentSupply = getCurrentSupplyWithoutInitialSupply(
            tokenAddress
        );
        return s_tokenStageSupply[tokenStage] - currentSupply;
    }

    function getTokensAmount() public view returns (uint256) {
        return s_tokens.length;
    }

    function getTokenAddress(uint256 _tokenId) public view returns (address) {
        return s_tokens[_tokenId];
    }

    function getFees() public view returns (uint256) {
        return i_fee;
    }

    function getOwnerAddress() public view returns (address) {
        return i_owner;
    }

    function getBuyerTokenAmountBought(
        address _tokenAddress,
        address _buyerAddress
    ) public view returns (uint256) {
        return s_buyerData[_tokenAddress][_buyerAddress].tokenAmountBought;
    }

    function getBuyerEthAmountSpent(
        address _tokenAddress,
        address _buyerAddress
    ) public view returns (uint256) {
        return s_buyerData[_tokenAddress][_buyerAddress].amountEthSpent;
    }

    ///////////////////////////
    // PUBLIC PURE FUNCTIONS //
    ///////////////////////////

    function getInitialSupply() public pure returns (uint256) {
        return INITIAL_SUPPLY;
    }

    function getMaxSupply() public pure returns (uint256) {
        return MAX_SUPPLY;
    }

    function getFundGoal() public pure returns (uint256) {
        return FUND_GOAL;
    }

    /////////////////////////////
    // EXTERNAL VIEW FUNCTIONS //
    /////////////////////////////

    //////////////////////
    // FALLBACK RECEIVE //
    //////////////////////

    fallback() external payable {}

    receive() external payable {}
}

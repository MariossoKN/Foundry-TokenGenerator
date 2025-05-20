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
        200000,
        400000,
        500000,
        550000,
        600000,
        650000,
        700000,
        800000
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
        address tokenCreatorAddress;
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
        s_tokenData[tokenAddress] = TokenData(
            msg.sender,
            0,
            0,
            block.timestamp,
            false
        );

        emit TokenCreated(address(newToken), INITIAL_SUPPLY, msg.sender);
        return tokenAddress;
    }

    function buyToken(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external payable {
        if (getTokenICOStatus(_tokenAddress) == true) {
            revert TokenGenerator__TokenICOReached();
        }
        if (
            getTokenDeadlineTimeLeft(_tokenAddress) >
            ICO_DEADLINE_IN_DAYS * 86400
        ) {
            revert TokenGenerator__ICODeadlineReached();
        }
        if (getTokenCreatorAddress(_tokenAddress) == address(0)) {
            revert TokenGenerator__WrongTokenAddress();
        }
        if (_tokenAmount < 1) {
            revert TokenGenerator__TokenAmountTooLow();
        }
        uint256 currentSupply = getCurrentSupplyWithoutInitialSupply(
            _tokenAddress
        );
        uint256 availableStageSupply = getAvailableStageSupply(_tokenAddress);
        if (_tokenAmount > availableStageSupply) {
            revert TokenGenerator__TokenAmountExceedsStageSellLimit(
                availableStageSupply
            );
        }

        uint256 tokensPrice = calculatePriceForTokens(
            _tokenAddress,
            _tokenAmount
        );
        if (msg.value < tokensPrice) {
            revert TokenGenerator__ValueSentIsLow(tokensPrice);
        }

        uint256 currentStageSupply = getTokenCurrentStageSupply(_tokenAddress);
        if ((_tokenAmount + currentSupply) == currentStageSupply) {
            s_tokenData[_tokenAddress].tokenStage += 1;
            s_tokenData[_tokenAddress].tokenAmountMinted += _tokenAmount;
            s_buyerData[_tokenAddress][msg.sender]
                .tokenAmountBought += _tokenAmount;
            s_buyerData[_tokenAddress][msg.sender].amountEthSpent += msg.value;
        } else {
            s_tokenData[_tokenAddress].tokenAmountMinted += _tokenAmount;
            s_buyerData[_tokenAddress][msg.sender]
                .tokenAmountBought += _tokenAmount;
            s_buyerData[_tokenAddress][msg.sender].amountEthSpent += msg.value;
        }

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

    function calculatePriceForTokens(
        address tokenAddress,
        uint256 tokenAmount
    ) public view returns (uint256) {
        uint256 pricePerToken = getTokenCurrentStagePrice(tokenAddress);

        return tokenAmount * pricePerToken;
    }

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

    function getTokenICOStatus(address _address) public view returns (bool) {
        return s_tokenData[_address].tokenICOActive;
    }

    function getTokenCreatorAddress(
        address _tokenAddress
    ) public view returns (address) {
        return s_tokenData[_tokenAddress].tokenCreatorAddress;
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

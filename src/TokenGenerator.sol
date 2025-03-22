// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Token} from "./Token.sol";

/**
 * @title TokenGenerator (PumpDotFun inspired)
 * @author Mariosso
 * @notice
 * @dev
 */

contract TokenGenerator {
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

    uint256 private immutable i_fee;
    address private immutable i_owner;

    // Token token;
    address[] private s_tokens;

    struct TokenData {
        address tokenCreator;
        uint256 tokensSold;
        uint256 fundGoal;
    }

    mapping(address tokenAddress => TokenData) private s_tokenData;

    error TokenGenerator__NotEnoughTokensLeft(uint256);
    error TokenGenerator__ValueSentCantBeZero();
    error TokenGenerator__FeesHasToBeBetweenOneAndTenThousand();
    error TokenGenerator__OnlyOwnerCanWithdraw();
    error TokenGenerator__ValueSentWrong(uint256);
    error TokenGenerator__ValueSentIsLow();
    error TokenGenerator__SaleEnded();
    error TokenGenerator__FundingGoalReached();
    error TokenGenerator__TokenAmountTooLow();
    error TokenGenerator__FundGoalTooLow();

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
        string memory _symbol,
        uint256 _tokenSupply, // 1000000000000000000000000 (1000000)
        uint256 _fundGoal
    ) external payable {
        if (msg.value < i_fee) {
            revert TokenGenerator__ValueSentIsLow();
        }
        if (_fundGoal < 100 ether) {
            revert TokenGenerator__FundGoalTooLow();
        }
        Token newToken = new Token(_name, _symbol, _tokenSupply, msg.sender);
        s_tokens.push(address(newToken));
        s_tokenData[address(newToken)] = TokenData(msg.sender, 0, _fundGoal);

        emit TokenCreated(address(newToken), _tokenSupply, msg.sender);
    }

    function buyToken(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external payable {
        if (_tokenAmount <= 1 ether) {
            revert TokenGenerator__TokenAmountTooLow();
        }

        uint256 fundGoal = getTokenFundGoal(_tokenAddress);
        Token token = Token(_tokenAddress);
        if (address(token).balance > fundGoal) {
            revert TokenGenerator__SaleEnded();
        }

        uint256 basePrice = calculateNewBasePrice(_tokenAddress);
        uint256 costOfTokens = calculateTokenCost(_tokenAmount, basePrice);
        if (msg.value < costOfTokens) {
            revert TokenGenerator__ValueSentWrong(costOfTokens);
        }

        s_tokenData[_tokenAddress].tokensSold += _tokenAmount;

        token.buy{value: msg.value};
        token.transfer(msg.sender, _tokenAmount);

        emit TokenBuy(address(_tokenAddress), _tokenAmount, msg.sender);
    }

    function withdrawFees() external {
        if (msg.sender != i_owner) {
            revert TokenGenerator__OnlyOwnerCanWithdraw();
        }
        (bool success, ) = (i_owner).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }

    ///////////////////////////
    // PUBLIC PURE FUNCTIONS //
    ///////////////////////////
    function calculateTokenCost(
        uint256 _tokenAmount,
        uint256 _basePrice
    ) public pure returns (uint256) {
        // basePrice = 0.1;   tokenAmount = 10
        //
        // baseCost = 10 * 0.1 = 1
        // incrementCost = (0.1 * (10 * (10 - 1))) / 2 = 4.5
        // 1 + 4.5 = 5.5

        // basePrice = 1;   tokenAmount = 10
        //
        // baseCost = 10 * 1 = 10
        // incrementCost = (1 * (10 * (10 - 1))) / 2 = 45
        // 10 + 45 = 55

        // basePrice = 1;   tokenAmount = 20
        //
        // baseCost = 20 * 1 = 20
        // incrementCost = (1 * (20 * (20 - 1))) / 2 = 190
        // 20 + 190 = 210
        uint256 baseCost = _tokenAmount * _basePrice;
        uint256 incrementCost = (_basePrice *
            (_tokenAmount * (_tokenAmount - 1))) / 2;
        return baseCost + incrementCost;
    }

    function calculateNewBasePrice(
        address _tokenAddress
    ) public view returns (uint256) {
        uint256 basePrice = 0.0001 ether;
        uint256 tokensSold = getTokenTokensSold(_tokenAddress);
        // basePrice = 0.1;   tokenAmount = 10
        //
        // (10 * 0.1) + 0.1 = 1.1

        // basePrice = 1;   tokenAmount = 10
        //
        // (10 * 1) + 1 = 11

        // basePrice = 1;   tokenAmount = 20
        //
        // (20 * 1) + 1 = 21
        return (tokensSold * basePrice) + basePrice;
    }

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////
    function getTokensAmount() public view returns (uint256) {
        return s_tokens.length;
    }

    function getToken(uint256 _tokenId) public view returns (address) {
        return s_tokens[_tokenId];
    }

    function getFees() public view returns (uint256) {
        return i_fee;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getTokenCreator(
        address _tokenAddress
    ) public view returns (address) {
        return s_tokenData[_tokenAddress].tokenCreator;
    }

    function getTokenFundGoal(
        address _tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[_tokenAddress].fundGoal;
    }

    function getTokenTokensSold(
        address _tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[_tokenAddress].tokensSold;
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

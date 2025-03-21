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

    uint256 basePrice = 0.0001 ether;

    // Token token;
    address[] private s_tokens;

    struct TokenData {
        address tokenCreator;
        uint256 tokensSold;
        uint256 amountSold;
        bool saleStatus;
    }

    mapping(address tokenAddress => TokenData) private s_tokenData;

    error TokenGenerator__NotEnoughTokensLeft(uint256);
    error TokenGenerator__ValueSentCantBeZero();
    error TokenGenerator__FeesHasToBeBetweenOneAndTenThousand();
    error TokenGenerator__OnlyOwnerCanWithdraw();
    error TokenGenerator__NotEnoughEthSent();

    /**
     * @dev
     */
    constructor(uint256 _fee) {
        if (_fee < 1 || _fee > 10000) {
            revert TokenGenerator__FeesHasToBeBetweenOneAndTenThousand();
        }
        i_fee = _fee;
        i_owner = msg.sender;
    }

    /**
     * @dev
     */
    function createToken(
        string memory _name,
        string memory _symbol,
        uint256 _tokenSupply // 1000000000000000000000000 (1000000)
    ) external payable {
        if (msg.value >= i_fee) {
            revert TokenGenerator__NotEnoughEthSent();
        }
        Token newToken = new Token(_name, _symbol, _tokenSupply, msg.sender);
        s_tokens.push(address(newToken));
        s_tokenData[address(newToken)] = TokenData(msg.sender, 0, 0, true);

        emit TokenCreated(address(newToken), _tokenSupply, msg.sender);
    }

    function buyToken(address _tokenAddress) external payable {
        if (msg.value == 0) {
            revert TokenGenerator__ValueSentCantBeZero();
        }
        Token token = Token(_tokenAddress);

        uint256 tokenSupply = token.totalSupply();
        uint256 remainingSupply = token.balanceOf(address(this));

        token.buy{value: msg.value};

        // token.transfer(msg.sender, tokenAmountBasedOnValueSent);

        // emit TokenBuy(
        //     address(_tokenAddress),
        //     tokenAmountBasedOnValueSent,
        //     msg.sender
        // );
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
        uint256 _tokenAmount
    ) public view returns (uint256) {
        uint256 baseCost = _tokenAmount * basePrice;
        uint256 incrementCost = (basePrice *
            (_tokenAmount * (_tokenAmount - 1))) / 2;
        return baseCost + incrementCost;
    }

    function calculateNewBasePrice(
        uint256 _tokenAmount,
        uint256 _tokensSold
    ) public view returns (uint256) {
        return basePrice + (basePrice * (_tokensSold + _tokenAmount));
    }

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////
    function getTokensAmount() public view returns (uint256) {
        return s_tokens.length;
    }

    function getFees() public view returns (uint256) {
        return i_fee;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getTokenData(
        address _tokenAddress
    ) public view returns (TokenData memory) {
        return s_tokenData[_tokenAddress];
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

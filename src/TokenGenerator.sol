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

    address[] private s_tokens;
    uint256 private constant MAX_SUPPLY = 1000000 ether;
    uint256 private constant INITIAL_SUPPLY = 200000 ether;
    uint256 private constant FUND_GOAL = 24 ether;

    struct TokenData {
        address tokenCreator;
        uint256 tokenCurrentSupply;
        uint256 fundingAmount;
    }

    mapping(address tokenAddress => TokenData) private s_tokenData;

    // Errors
    error TokenGenerator__NotEnoughTokensLeft(uint256);
    error TokenGenerator__ValueSentCantBeZero();
    error TokenGenerator__FeesHasToBeBetweenOneAndTenThousand();
    error TokenGenerator__OnlyOwnerCanWithdraw();
    error TokenGenerator__ValueSentWrong(uint256);
    error TokenGenerator__ValueSentIsLow();
    error TokenGenerator__AmountExceedsTheFundGoal();
    error TokenGenerator__FundingGoalReached();
    error TokenGenerator__TokenAmountTooLow();
    error TokenGenerator__WrongTokenAddress();
    error TokenGenerator__TokenAmountExceedsTheMaxSupply();

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
            revert TokenGenerator__ValueSentIsLow();
        }

        Token newToken = new Token(_name, _symbol, INITIAL_SUPPLY, msg.sender);
        address tokenAddress = address(newToken);

        s_tokens.push(tokenAddress);
        s_tokenData[tokenAddress] = TokenData(msg.sender, INITIAL_SUPPLY, 0);

        emit TokenCreated(address(newToken), INITIAL_SUPPLY, msg.sender);
        return tokenAddress;
    }

    function buyToken(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external payable {
        if (getTokenCreator(_tokenAddress) == address(0)) {
            revert TokenGenerator__WrongTokenAddress();
        }
        if (_tokenAmount < 1) {
            revert TokenGenerator__TokenAmountTooLow();
        }
        uint256 tokenAmountInWei = _tokenAmount * 10 ** 18;
        uint256 tokenCurrentSupply = getTokenCurrentSupply(_tokenAddress);
        if ((tokenCurrentSupply + tokenAmountInWei) > MAX_SUPPLY) {
            revert TokenGenerator__TokenAmountExceedsTheMaxSupply();
        }

        uint256 currentFundingAmount = getTokenCurrentFundingAmount(
            _tokenAddress
        );
        Token token = Token(_tokenAddress);
        if (currentFundingAmount + msg.value > FUND_GOAL) {
            revert TokenGenerator__AmountExceedsTheFundGoal();
        }

        uint256 costOfTokens = calculateTokensCost(
            _tokenAddress,
            tokenAmountInWei
        );
        if (msg.value < costOfTokens) {
            revert TokenGenerator__ValueSentWrong(costOfTokens);
        }

        s_tokenData[_tokenAddress].tokenCurrentSupply += tokenAmountInWei;
        s_tokenData[_tokenAddress].fundingAmount += msg.value;

        token.buy{value: msg.value}(msg.sender, tokenAmountInWei);

        emit TokenBuy(address(_tokenAddress), tokenAmountInWei, msg.sender);
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

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////
    function calculateTokensCost(
        address _tokenAddress,
        uint256 _tokenAmount
    ) public view returns (uint256) {
        uint256 tokensSold = getTokenCurrentSupply(_tokenAddress);
        return (tokensSold * 0.0001 ether) * (_tokenAmount / 10 ** 18);
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

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getTokenCreator(
        address _tokenAddress
    ) public view returns (address) {
        return s_tokenData[_tokenAddress].tokenCreator;
    }

    function getTokenCurrentFundingAmount(
        address _tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[_tokenAddress].fundingAmount;
    }

    function getTokenRemainingFundingAmount(
        address _tokenAddress
    ) public view returns (uint256) {
        uint256 currentFundingAmount = getTokenCurrentFundingAmount(
            _tokenAddress
        );
        if (currentFundingAmount >= FUND_GOAL) {
            return 0;
        }
        return FUND_GOAL - currentFundingAmount;
    }

    function getTokenCurrentSupply(
        address _tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[_tokenAddress].tokenCurrentSupply;
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

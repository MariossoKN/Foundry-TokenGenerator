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
    uint256 private constant INITIAL_SUPPLY = 200000 ether; // 20% of max supply
    uint256 private constant FUND_GOAL = 24 ether;
    uint256 private constant INITIAL_PRICE = 0.00003 ether;
    uint256 public constant K = 8 * 10 ** 15; // Growth rate (k), scaled to avoid precision loss (0.01 * 10^18)
    uint256 DECIMALS = 10 ** 18;

    struct TokenData {
        address tokenCreator;
        uint256 fundingAmount;
    }

    mapping(address tokenAddress => TokenData tokenData) private s_tokenData;

    // Errors
    error TokenGenerator__OnlyOwnerCanWithdraw();
    error TokenGenerator__ValueSentWrong(uint256);
    error TokenGenerator__ValueSentIsLow();
    error TokenGenerator__AmountExceedsTheFundGoal();
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
        s_tokenData[tokenAddress] = TokenData(msg.sender, 0);

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
        // uint256 tokenAmountInWei = _tokenAmount * 10 ** 18;
        // uint256 tokenCurrentSupply = Token(_tokenAddress).totalSupply();
        // if (
        //     (tokenCurrentSupply + tokenAmountInWei) >
        //     (MAX_SUPPLY - INITIAL_SUPPLY)
        // ) {
        //     revert TokenGenerator__TokenAmountExceedsTheMaxSupply();
        // }

        uint256 currentFundingAmount = getTokenCurrentFundingAmount(
            _tokenAddress
        );
        if (currentFundingAmount + msg.value > FUND_GOAL) {
            revert TokenGenerator__AmountExceedsTheFundGoal();
        }

        uint256 tokenSupply = (Token(_tokenAddress).totalSupply()) -
            INITIAL_SUPPLY;

        uint256 costOfTokens = calculateTokenCost(tokenSupply, _tokenAmount);
        if (msg.value < costOfTokens) {
            revert TokenGenerator__ValueSentWrong(costOfTokens);
        }

        s_tokenData[_tokenAddress].fundingAmount += msg.value;

        Token token = Token(_tokenAddress);
        token.buy{value: msg.value}(msg.sender, _tokenAmount);

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

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////

    // Function to calculate the cost in wei for purchasing `tokensToBuy` starting from `currentSupply`
    function calculateTokenCost(
        uint256 currentSupply,
        uint256 tokensToBuy
    ) public pure returns (uint256) {
        // Calculate the exponent parts scaled to avoid precision loss
        uint256 exponent1 = (K * (currentSupply + tokensToBuy)) / 10 ** 18;
        uint256 exponent2 = (K * currentSupply) / 10 ** 18;

        // Calculate e^(kx) using the exp function
        uint256 exp1 = exp(exponent1);
        uint256 exp2 = exp(exponent2);

        // Cost formula: (P0 / k) * (e^(k * (currentSupply + tokensToBuy)) - e^(k * currentSupply))
        // We use (P0 * 10^18) / k to keep the division safe from zero
        uint256 cost = (INITIAL_PRICE * 10 ** 18 * (exp1 - exp2)) / K; // Adjust for k scaling without dividing by zero
        return cost;
    }

    // Improved helper function to calculate e^x for larger x using a Taylor series approximation
    function exp(uint256 x) internal pure returns (uint256) {
        uint256 sum = 10 ** 18; // Start with 1 * 10^18 for precision
        uint256 term = 10 ** 18; // Initial term = 1 * 10^18
        uint256 xPower = x; // Initial power of x

        for (uint256 i = 1; i <= 20; i++) {
            // Increase iterations for better accuracy
            term = (term * xPower) / (i * 10 ** 18); // x^i / i!
            sum += term;

            // Prevent overflow and unnecessary calculations
            if (term < 1) break;
        }

        return sum;
    }

    function getInitialSupply() public pure returns (uint256) {
        return INITIAL_SUPPLY;
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

    /////////////////////////////
    // EXTERNAL VIEW FUNCTIONS //
    /////////////////////////////

    //////////////////////
    // FALLBACK RECEIVE //
    //////////////////////
    fallback() external payable {}

    receive() external payable {}
}

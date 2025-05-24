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
    error TokenGenerator__ValueSentIsLow(uint256);
    error TokenGenerator__TokenAmountTooLow();
    error TokenGenerator__WrongTokenAddress();
    error TokenGenerator__TokenAmountExceedsMaxSupply();
    error TokenGenerator__ICODeadlineReached();
    error TokenGenerator__TokenICOReached();
    error TokenGenerator__TokenSaleStillActive();
    error TokenGenerator__WrongStageCalculation();
    error TokenGenerator__CantBeZeroAddress();

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

    event FundsWithdrawed(
        address indexed tokenAddress,
        address indexed callerAddres,
        uint256 indexed ethAmountWithdrawed
    );

    event OwnerAddressChanged(address indexed newOwnerAddress);

    // Storage variables
    uint256 private immutable i_fee;
    uint256 private immutable i_icoDeadlineInDays;
    address private s_owner;

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
    uint256 private constant MAX_SUPPLY = 1e6;
    uint256 private constant INITIAL_SUPPLY = 2e5; // 20% of max supply
    uint256 private constant FUND_GOAL = 21 ether;

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

    modifier onlyContractOwner() {
        if (msg.sender != s_owner) {
            revert TokenGenerator__OnlyOwnerCanWithdraw();
        }
        _;
    }

    /**
     * @dev
     */
    constructor(uint256 _fee, uint256 _icoDeadlineInDays) {
        i_fee = _fee;
        s_owner = msg.sender;
        i_icoDeadlineInDays = _icoDeadlineInDays;
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

    function buyToken(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external payable {
        if (
            getCurrentSupplyWithoutInitialSupply(_tokenAddress) + _tokenAmount >
            MAX_SUPPLY - INITIAL_SUPPLY
        ) {
            revert TokenGenerator__TokenAmountExceedsMaxSupply();
        }
        if (_tokenAddress == address(0)) {
            revert TokenGenerator__CantBeZeroAddress();
        }
        if (getTokenICOStatus(_tokenAddress)) {
            revert TokenGenerator__TokenICOReached();
        }
        if (
            getTokenDeadlineTimeLeft(_tokenAddress) >
            i_icoDeadlineInDays * 86400
        ) {
            revert TokenGenerator__ICODeadlineReached();
        }
        if (getTokenCreationTimestamp(_tokenAddress) == 0) {
            revert TokenGenerator__WrongTokenAddress();
        }
        if (_tokenAmount == 0) {
            revert TokenGenerator__TokenAmountTooLow();
        }
        // check new stage and calculate price
        uint256 newStage = checkNewStage(_tokenAddress, _tokenAmount);
        uint256 tokensPrice = calculatePriceForTokens(
            _tokenAddress,
            _tokenAmount,
            newStage
        );
        if (msg.value != tokensPrice) {
            revert TokenGenerator__ValueSentIsLow(tokensPrice);
        }
        // update token/buyer data
        s_tokenData[_tokenAddress].tokenStage = newStage;
        s_tokenData[_tokenAddress].tokenAmountMinted += _tokenAmount;
        s_buyerData[_tokenAddress][msg.sender]
            .tokenAmountBought += _tokenAmount;
        s_buyerData[_tokenAddress][msg.sender].amountEthSpent += msg.value;
        // if max supply is sold, change ICO status to true
        if (
            getCurrentSupplyWithoutInitialSupply(_tokenAddress) ==
            (MAX_SUPPLY - INITIAL_SUPPLY)
        ) {
            s_tokenData[_tokenAddress].tokenICOActive = true;
        }
        // send ETH to token contract and mint NFTs to token contract
        Token token = Token(_tokenAddress);
        token.buy{value: msg.value}(_tokenAddress, _tokenAmount);

        emit TokenBuy(address(_tokenAddress), _tokenAmount, msg.sender);
    }

    function checkNewStage(
        address _tokenAddress,
        uint256 _tokenAmount
    ) public view returns (uint256 newStage) {
        uint256 tokenStage = getTokenStage(_tokenAddress);
        uint256 newTokenSupply = getCurrentSupplyWithoutInitialSupply(
            _tokenAddress
        ) + _tokenAmount;
        if (newTokenSupply == MAX_SUPPLY - INITIAL_SUPPLY) {
            return 7;
        }
        for (uint256 i = tokenStage; i < 8; i++) {
            if (s_tokenStageSupply[i] > newTokenSupply) {
                return i;
            }
        }
    }

    /**
     * @notice Calculates the total price for purchasing a specified amount of tokens
     * @param _tokenAddress The address of the token being purchased
     * @param _tokenAmount The amount of tokens to purchase
     * @param _newStage The stage the token will reach after this purchase
     * @return tokensPrice The total price in wei for the token purchase
     * @dev This function accounts for tier-based pricing across multiple stages
     */
    function calculatePriceForTokens(
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
        // current supply = 120000
        // current stage = 0
        // we are buying = 235000
        // new stage = 1

        // i = 0 ; i <= 1 True
        // i = 1 ; i <= 1 True
        for (uint256 i = startingStage; i <= _newStage; ) {
            uint256 stageSupplyLimit = s_tokenStageSupply[i];
            // 200000
            // 200000
            uint256 availableInStage = stageSupplyLimit - tokenCurrentSupply;
            // 80000 = 200000 - 120000
            // 200000 = 400000 - 200000

            if (tokenAmountLeft <= availableInStage) {
                // 235000 <= 80000
                // 155000 <= 200000
                tokensPrice += s_tokenStagePrice[i] * tokenAmountLeft;
                // 0.24 + (0,0000045 * 155000) = 0,9375
                return tokensPrice;
            } else {
                tokensPrice += s_tokenStagePrice[i] * availableInStage;
                // 0.24 = 0,000003 * 80000
                tokenCurrentSupply = stageSupplyLimit;
                // 200000
                tokenAmountLeft -= availableInStage;
                // 235000 - 80000 = 155000
            }

            ++i;
        }
        // This should never be reached with proper input validation
        return tokensPrice;
    }

    function withdrawFunds(address _tokenAddress) external payable {
        if (
            i_icoDeadlineInDays * 86400 >
            getTokenDeadlineTimeLeft(_tokenAddress)
        ) {
            revert TokenGenerator__TokenSaleStillActive();
        }
        if (getTokenICOStatus(_tokenAddress)) {
            revert TokenGenerator__TokenICOReached();
        }
        uint256 amountToWithdraw = s_buyerData[_tokenAddress][msg.sender]
            .amountEthSpent;

        s_buyerData[_tokenAddress][msg.sender].amountEthSpent = 0;

        Token(_tokenAddress).withdrawBuyerFunds(msg.sender, amountToWithdraw);
        emit FundsWithdrawed(
            address(_tokenAddress),
            msg.sender,
            amountToWithdraw
        );
    }

    function withdrawFees() external onlyContractOwner {
        (bool success, ) = (s_owner).call{value: address(this).balance}("");
        require(success, "Fees withdraw failed");
    }

    function changeContractOwner(
        address _newOwnerAddress
    ) external onlyContractOwner {
        if (_newOwnerAddress == address(0)) {
            revert TokenGenerator__CantBeZeroAddress();
        }
        s_owner = _newOwnerAddress;

        emit OwnerAddressChanged(_newOwnerAddress);
    }

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////
    function getCurrentSupplyWithoutInitialSupply(
        address tokenAddress
    ) public view returns (uint256) {
        return s_tokenData[tokenAddress].tokenAmountMinted;
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

    function getTokenStage(address tokenAddress) public view returns (uint256) {
        return s_tokenData[tokenAddress].tokenStage;
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

    function getTokenCreatorAddress(
        address _tokenAddress
    ) external view returns (address) {
        return Token(_tokenAddress).getTokenCreator();
    }

    function getTokenCurrentStageSupply(
        address tokenAddress
    ) external view returns (uint256) {
        uint256 tokenStage = getTokenStage(tokenAddress);
        return s_tokenStageSupply[tokenStage];
    }

    function getTokenCurrentStagePrice(
        address tokenAddress
    ) external view returns (uint256) {
        uint256 tokenStage = getTokenStage(tokenAddress);
        return s_tokenStagePrice[tokenStage];
    }

    function getTokensAmount() external view returns (uint256) {
        return s_tokens.length;
    }

    function getTokenAddress(uint256 _tokenId) external view returns (address) {
        return s_tokens[_tokenId];
    }

    function getAvailableStageSupply(
        address tokenAddress
    ) external view returns (uint256) {
        uint256 tokenStage = getTokenStage(tokenAddress);
        uint256 currentSupply = getCurrentSupplyWithoutInitialSupply(
            tokenAddress
        );
        return s_tokenStageSupply[tokenStage] - currentSupply;
    }

    function getBuyerTokenAmountBought(
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

    function getFees() external view returns (uint256) {
        return i_fee;
    }

    function getOwnerAddress() external view returns (address) {
        return s_owner;
    }

    function getIcoDeadline() external view returns (uint256) {
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
        return FUND_GOAL;
    }

    //////////////////////
    // FALLBACK RECEIVE //
    //////////////////////

    fallback() external payable {}

    receive() external payable {}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Token (PumpDotFun inspired)
 * @author Mariosso
 * @notice
 * @dev
 */

contract Token is ERC20 {
    // Modifiers
    modifier onlyTokenGenerator() {
        if (msg.sender != i_tokenGenerator) {
            revert Token__OnlyTokenGeneratorContractCanCallThis();
        }
        _;
    }

    // Storage values
    address private immutable i_tokenCreator;
    address private immutable i_tokenGenerator;

    // Errors
    error Token__OnlyTokenGeneratorContractCanCallThis();
    error Token__ExceededTheMaxFundedAmount();

    /**
     * @dev
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _tokenCreator
    ) ERC20(_name, _symbol) {
        i_tokenCreator = _tokenCreator;
        i_tokenGenerator = msg.sender;

        _mint(msg.sender, _initialSupply);
    }

    /**
     * @dev
     */
    function buy(
        address _callerAddress,
        uint256 _amount
    ) external payable onlyTokenGenerator {
        _mint(_callerAddress, _amount);
    }

    function withdrawBuyerFunds(
        address _to,
        uint256 _amount
    ) external payable onlyTokenGenerator {
        (bool success, ) = (_to).call{value: _amount}("");
        require(success, "Funds withdraw failed");
    }

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////
    function getTokenCreator() public view returns (address) {
        return i_tokenCreator;
    }

    function getTokenGeneratorAddress() public view returns (address) {
        return i_tokenGenerator;
    }

    /////////////////////////////
    // EXTERNAL VIEW FUNCTIONS //
    /////////////////////////////

    //////////////////////
    // FALLBACK RECEIVE //
    //////////////////////
}

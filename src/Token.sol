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
    // Storage values
    address private immutable i_tokenCreator;
    address private immutable i_tokenGenerator;

    // Errors
    error Token__OnlyTokenGeneratorContractCanCallThis();

    /**
     * @dev
     */
    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _initialSupply,
        address _tokenCreator
    ) ERC20(_tokenName, _tokenSymbol) {
        i_tokenCreator = _tokenCreator;
        i_tokenGenerator = msg.sender;

        _mint(msg.sender, _initialSupply);
    }

    /**
     * @dev
     */
    function mint(uint256 _amount) external payable {
        if (msg.sender != i_tokenGenerator) {
            revert Token__OnlyTokenGeneratorContractCanCallThis();
        }
        _mint(i_tokenGenerator, _amount);
    }

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////
    function getTokenCreator() external view returns (address) {
        return i_tokenCreator;
    }

    function getTokenGeneratorAddress() external view returns (address) {
        return i_tokenGenerator;
    }

    /////////////////////////////
    // EXTERNAL VIEW FUNCTIONS //
    /////////////////////////////

    //////////////////////
    // FALLBACK RECEIVE //
    //////////////////////
}

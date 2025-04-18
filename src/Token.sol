// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Token (PumpDotFun inspired)
 * @author Mariosso
 * @notice
 * @dev
 */

contract Token is ERC20 {
    address private immutable i_tokenCreator;
    address private immutable i_tokenGenerator;

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
    function buy(address _callerAddress, uint256 _amount) external payable {
        _mint(_callerAddress, _amount);
    }

    ///////////////////////////
    // PUBLIC VIEW FUNCTIONS //
    ///////////////////////////
    function getTokenCreator() public view returns (address) {
        return i_tokenCreator;
    }

    /////////////////////////////
    // EXTERNAL VIEW FUNCTIONS //
    /////////////////////////////

    //////////////////////
    // FALLBACK RECEIVE //
    //////////////////////
}

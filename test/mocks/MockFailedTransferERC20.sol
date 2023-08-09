// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title StableCoin
 * author Torok Mark Patrik
 * MOCK ERC20 TOKEN
 */
contract MockFailedTransferERC20 is ERC20, Ownable {
    error StableCoin__BurnAmountIsMoreThanBalance();
    error StableCoin__MustBeMoreThanZero();
    error StableCoin__ZeroAddress();

    constructor() ERC20("StableCoin", "SC") Ownable(msg.sender) {}

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_amount <= 0) {
            revert StableCoin__MustBeMoreThanZero();
        }

        if (_to == address(0)) {
            revert StableCoin__ZeroAddress();
        }
        _mint(_to, _amount);
        return true;
    }

    function transfer(
        address,
        /*recipient*/ uint256 /*amount*/
    ) public pure override returns (bool) {
        return false;
    }
}

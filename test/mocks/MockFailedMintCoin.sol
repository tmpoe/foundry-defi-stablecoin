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

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title StableCoin
 * author Torok Mark Patrik
 * Collateral: Exogenous (BTC, ETH)
 * Stability: Anchored to USD
 * Minting: Algorithmic
 *
 * This is a stable coin governed by SCEngine. This contract is the ERC20 implementation of a stable coin system.
 *
 */
contract MockFailedMintCoin is ERC20Burnable, Ownable {
    error StableCoin__BurnAmountIsMoreThanBalance();
    error StableCoin__MustBeMoreThanZero();
    error StableCoin__ZeroAddress();

    constructor() ERC20("StableCoin", "SC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        if (_amount > balanceOf(msg.sender)) {
            revert StableCoin__BurnAmountIsMoreThanBalance();
        }

        if (_amount <= 0) {
            revert StableCoin__MustBeMoreThanZero();
        }
        super.burn(_amount);
    }

    function mint(
        address /*_to*/,
        uint256 /*_amount*/
    ) external view onlyOwner returns (bool) {
        return false;
    }
}

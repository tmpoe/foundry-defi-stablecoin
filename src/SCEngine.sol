// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * @title SCEngine
 * @author Mark Patrik Torok
 * This contract is the engine for the StableCoin contract
 * Very minimal and simplistic implementatition with the main goal of a peg 1 USD == 1 SC
 * Properties:
 * Collateral: Exogenous (BTC, ETH)
 * Anchor: USD
 * Stability: Algorithmic
 *
 * The system shall be overcollateralized at all times. At no point shall the value of the collateral be less than or equal the USD value of the stable coin.
 *
 * @notice This is the core of this stable coin system. It handles minting, redeeming, depositing and withdrawing.
 * @notice Loosely based on DAI without no governance, fees and is backed only by WETH and WBTC.
 */
contract SCEngine {
    function mintSCWithCollateral() external {}

    function mintSc() external {}

    function redeemCollateralForSC() external {}

    function redeemSCForCollateral() external {}

    function depositCollateral() external {}

    function burnSCForCollateral() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}

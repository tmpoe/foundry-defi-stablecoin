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
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StableCoin} from "./StableCoin.sol";

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
contract SCEngine is ReentrancyGuard {
    error SCEngine__MustBeMoreThanZero();
    error SCEngine__NotAllowedTokenCollateral();
    error SCEngine__TokenAddressesAndPriceFeedAddressesMustBeEqualLengths();
    error SCEngine__TransferFailed();

    mapping(address => address) private s_priceFeeds;
    mapping(address => mapping(address => uint256)) private s_collateralBalances;
    mapping(address => uint256) private s_SCMinted;

    address[] private s_tokenCollateralAddresses;

    StableCoin private immutable i_stableCoin;

    event CollateralDeposited(address indexed depositor, address indexed tokenCollateralAddress, uint256 amount);

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert SCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedTokenCollateral(address tokenCollateralAddress) {
        if (s_priceFeeds[tokenCollateralAddress] == address(0)) {
            revert SCEngine__NotAllowedTokenCollateral();
        }
        _;
    }

    constructor(
        address[] memory tokenCollateralAddresses,
        address[] memory priceFeedAddresses,
        address stableCoinAddress
    ) {
        if (tokenCollateralAddresses.length != priceFeedAddresses.length) {
            revert SCEngine__TokenAddressesAndPriceFeedAddressesMustBeEqualLengths();
        }

        for (uint256 i = 0; i < tokenCollateralAddresses.length; i++) {
            s_priceFeeds[tokenCollateralAddresses[i]] = priceFeedAddresses[i];
            s_tokenCollateralAddresses.push(tokenCollateralAddresses[i]);
        }

        i_stableCoin = StableCoin(stableCoinAddress);
    }

    function mintSCWithCollateral() external {}

    /*
     * @notice Follows CEI
     * @param amountToMint The amount of stable coins to mint
     */
    function mintSc(uint256 amountToMint) external nonReentrant {
        s_SCMinted[msg.sender] += amountToMint;
    }

    function redeemCollateralForSC() external {}

    function redeemSCForCollateral() external {}

    /*
    * @notice Followes CEI
     * @param tokenCollateralAddress The address of the collateral token
     * @param amount The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amount)
        external
        moreThanZero(amount)
        isAllowedTokenCollateral(tokenCollateralAddress)
        nonReentrant
    {
        // Checks in modifiers
        // Effects
        s_collateralBalances[msg.sender][tokenCollateralAddress] += amount;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amount);

        // Interactions
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    function burnSCForCollateral() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalSCMinted, uint256 totalCollateralValueInUSD)
    {
        totalSCMinted = s_SCMinted[user];
        totalCollateralValueInUSD = getCollateralValue(user);
    }

    function _checkUserHealthFactor(address user) internal view {
        // Get user health factor
        // If below 1, revert
    }

    /*
    * Returns how close the user is to being liquidated
    * @param userAddress The address of the user
    */
    function _getUserHealthFactor(address user) internal view {
        (uint256 totalSCMinted, uint256 totalCollateralValueInUSD) = _getAccountInformation(user);
    }

    function getCollateralValue(address user) public view returns (uint256) {
        for (uint256 i = 0; i < s_tokenCollateralAddresses.length; i++) {
            // get price feed
        }
    }
}

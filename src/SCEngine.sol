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
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";

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
    error SCEngine__NotEnoughCollateral();
    error SCEngine__MintFailed();

    mapping(address => address) private s_priceFeeds;
    mapping(address => mapping(address => uint256))
        private s_collateralBalances;
    mapping(address => uint256) private s_SCMinted;

    address[] private s_tokenCollateralAddresses;

    StableCoin private immutable i_stableCoin;

    uint256 private constant ADDITIONAL_PRICE_FEE_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    event CollateralDeposited(
        address indexed depositor,
        address indexed tokenCollateralAddress,
        uint256 amount
    );

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
    function mintSC(
        uint256 amountToMint
    ) external nonReentrant moreThanZero(amountToMint) {
        s_SCMinted[msg.sender] += amountToMint;
        _checkUserHealthFactor(msg.sender);
        bool success = i_stableCoin.mint(msg.sender, amountToMint);
        if (!success) {
            revert SCEngine__MintFailed();
        }
    }

    function redeemCollateralForSC() external {}

    function redeemSCForCollateral() external {}

    /*
     * @notice Followes CEI
     * @param tokenCollateralAddress The address of the collateral token
     * @param amount The amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amount
    )
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
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    function burnSCForCollateral() external {}

    function liquidate() external {}

    function getHealthFactor(address user) external view returns (uint256) {
        return _getUserHealthFactor(user);
    }

    function _getAccountInformation(
        address user
    )
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
        uint256 healthFactor = _getUserHealthFactor(user);
        console.log("Health factor: %s", healthFactor);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert SCEngine__NotEnoughCollateral();
        }
    }

    /*
     * Returns how close the user is to being liquidated
     * @param userAddress The address of the user
     */
    function _getUserHealthFactor(
        address user
    ) internal view returns (uint256) {
        (
            uint256 totalSCMinted,
            uint256 totalCollateralValueInUSD
        ) = _getAccountInformation(user);
        console.log("Total SC minted: %s", totalSCMinted);
        console.log(
            "Total collateral value in USD: %s",
            totalCollateralValueInUSD
        );
        if (totalSCMinted == 0) return type(uint256).max;
        uint256 collateralAdjustesForThreshold = (totalCollateralValueInUSD *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustesForThreshold * PRECISION) / totalSCMinted;
    }

    function getCollateralValue(address user) public view returns (uint256) {
        uint256 totalCollateralValueInUSD = 0;
        for (uint256 i = 0; i < s_tokenCollateralAddresses.length; i++) {
            // get price feed
            address token = s_tokenCollateralAddresses[i];
            uint256 amount = s_collateralBalances[user][token];
            totalCollateralValueInUSD += getUsdValue(token, amount);
        }
        return totalCollateralValueInUSD;
    }

    function getUsdValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            (uint256(price) * ADDITIONAL_PRICE_FEE_PRECISION * amount) /
            PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }
}

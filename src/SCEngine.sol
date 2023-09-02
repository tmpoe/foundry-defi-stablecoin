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
    error SCEngine__WouldBreakHealthFactor();
    error SCEngine__MintFailed();
    error SCEngine__HealthFactorOk();
    error SCEngine__HealthFactorStillBroken();

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
    uint256 private constant LIQUIDATION_BONUS = 10; //%

    event CollateralDeposited(
        address indexed depositor,
        address indexed tokenCollateralAddress,
        uint256 amount
    );

    event CollateralRedeemed(
        address indexed from,
        address indexed redeemer,
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

    /*
     * @param collateral The address of the collateral token
     * @param amountCollateral The amount of collateral to deposit
     * @param amountSCToMint The amount of stable coins to mint
     * @notice Will deposit collateral and mint stable coins
     */
    function mintSCWithCollateral(
        address collateral,
        uint256 amountCollateral,
        uint256 amountSCToMint
    ) external {
        depositCollateral(collateral, amountCollateral);
        mintSC(amountSCToMint);
    }

    /*
     * @notice Follows CEI
     * @param amountToMint The amount of stable coins to mint
     */
    function mintSC(
        uint256 amountToMint
    ) public nonReentrant moreThanZero(amountToMint) {
        s_SCMinted[msg.sender] += amountToMint;
        _checkUserHealthFactor(msg.sender);
        bool success = i_stableCoin.mint(msg.sender, amountToMint);
        if (!success) {
            revert SCEngine__MintFailed();
        }
    }

    function redeemCollateral(
        address collateral,
        uint256 amountToRedeem
    )
        public
        isAllowedTokenCollateral(collateral)
        nonReentrant
        moreThanZero(amountToRedeem)
    {
        _redeemCollateral(collateral, amountToRedeem, msg.sender, msg.sender);
        _checkUserHealthFactor(msg.sender);
    }

    /*
     * @param scAmountToBurn The amount of stable coins to burn
     * @param collateral The address of the collateral token
     * @param collateralAmountToRedeem The amount of collateral to redeem
     */
    function redeemCollateralForSC(
        uint256 scAmountToBurn,
        address collateral,
        uint256 collateralAmountToRedeem
    ) public {
        burnSC(scAmountToBurn);
        redeemCollateral(collateral, collateralAmountToRedeem);
    }

    /*
     * @notice Followes CEI
     * @param collateral The address of the collateral token
     * @param amount The amount of collateral to deposit
     */
    function depositCollateral(
        address collateral,
        uint256 amount
    )
        public
        moreThanZero(amount)
        isAllowedTokenCollateral(collateral)
        nonReentrant
    {
        // Checks in modifiers
        // Effects
        s_collateralBalances[msg.sender][collateral] += amount;
        emit CollateralDeposited(msg.sender, collateral, amount);

        // Interactions
        bool success = IERC20(collateral).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    function burnSC(uint256 amount) public moreThanZero(amount) {
        _burnSC(msg.sender, amount, msg.sender);
    }

    /*
     * @param collateral The address of the collateral token
     * @param user The address of the user whose health factor is broken
     * @param debtToCover The amount of SC to burn to repair health factor
     */
    function liquidate(
        address collateral,
        address user,
        uint256 debtToCover
    ) external moreThanZero(debtToCover) {
        uint256 startingHealthFactor = _getUserHealthFactor(user);

        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SCEngine__HealthFactorOk();
        }

        uint256 tokenAmountFromDebtCovered = _getTokenAmountFromUsd(
            collateral,
            debtToCover
        );

        uint256 collateralBonus = tokenAmountFromDebtCovered /
            LIQUIDATION_BONUS; // is this dangerous? will test

        console.log("Collateral bonus: %s", collateralBonus);
        console.log(
            "Token amount from debt covered: %s",
            tokenAmountFromDebtCovered
        );
        _redeemCollateral(
            collateral,
            tokenAmountFromDebtCovered + collateralBonus,
            user,
            msg.sender
        );
        _burnSC(user, debtToCover, msg.sender);

        uint256 endingHealthFactor = _getUserHealthFactor(user);

        if (endingHealthFactor < MIN_HEALTH_FACTOR) {
            revert SCEngine__HealthFactorStillBroken();
        }
    }

    function _getTokenAmountFromUsd(
        address collateral,
        uint256 usdAmountInWei
    ) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[collateral]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // wei * 10^18 / 10^8 * 10^10 -> wei will be in wei magnitude
        return
            (usdAmountInWei * PRECISION) /
            (uint256(price) * ADDITIONAL_PRICE_FEE_PRECISION);
    }

    function _redeemCollateral(
        address collateral,
        uint256 collateralToRedeem,
        address from,
        address to
    ) private {
        // Will automatically revert if not enough collateral - safemaths
        s_collateralBalances[from][collateral] -= collateralToRedeem;

        emit CollateralRedeemed(from, to, collateral, collateralToRedeem);
        console.log("Collateral to redeem: %s", collateralToRedeem);
        console.log("Collateral address: %s", collateral);
        console.log("To address: %s", to);
        console.log("From address: %s", from);
        bool success = IERC20(collateral).transfer(to, collateralToRedeem);

        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    /*
     * @dev Make sure whatever calls this method also checks health factor. Health factor
     * shall not be broken
     */
    function _burnSC(address onBehalfOf, uint256 amount, address from) private {
        s_SCMinted[onBehalfOf] -= amount;
        console.log("Amount to burn: %s", amount);
        console.log("Amount from address: %s", getSCBalance(from));
        bool success = i_stableCoin.transferFrom(from, address(this), amount);

        if (!success) {
            revert SCEngine__TransferFailed();
        }

        i_stableCoin.burn(amount);
        console.log("Amount post burn from address: %s", getSCBalance(from));
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
            revert SCEngine__WouldBreakHealthFactor();
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

    function getHealthFactor(address user) external view returns (uint256) {
        return _getUserHealthFactor(user);
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getSCBalance(address user) public view returns (uint256) {
        return s_SCMinted[user];
    }

    function getAccountInformation(
        address user
    )
        external
        view
        returns (uint256 totalSCMinted, uint256 totalCollateralValueInUSD)
    {
        (totalSCMinted, totalCollateralValueInUSD) = _getAccountInformation(
            user
        );
    }

    function getStableCoinAddress() public view returns (address) {
        return address(i_stableCoin);
    }

    function getCollateralAddresses() public view returns (address[] memory) {
        return s_tokenCollateralAddresses;
    }
}

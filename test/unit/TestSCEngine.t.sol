// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {StableCoin} from "../../src/StableCoin.sol";
import {Config} from "../../script/Config.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {DeploySCEngine} from "../../script/DeploySCEngine.s.sol";

contract TestSCEngine is Test {
    Config config;
    uint256 deployerKey;
    SCEngine scEngine;
    address weth;
    address wbtc;
    StableCoin stableCoin;

    address constant USER = address(1337);
    uint256 constant COLLATERAL_AMOUNT = 1e18;
    uint256 constant DEPOSITED_USD_VALUE = 2e21; // 2000 USD
    uint256 constant MINT_USD_VALUE_TO_MINT_WITH_ONE_COLLATERAL =
        DEPOSITED_USD_VALUE / 4;
    uint256 constant MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL =
        DEPOSITED_USD_VALUE / 2;

    function setUp() external {
        DeploySCEngine deploySCEngine = new DeploySCEngine();
        (scEngine, config) = deploySCEngine.run();
        (, , weth, wbtc, deployerKey) = config.activeNetworkConfig();
        stableCoin = StableCoin(scEngine.getStableCoinAddress());
    }

    address[] public tokens;
    address[] public priceFeeds;

    /*
     * GIVEN: An SCEngine contract
     * WHEN: SCEngine is instantiated with mismatching token and price feed lengths
     * THEN: Instantiation reverts
     */
    function test_constructorRevertsIfTokensAndPriceFeedsLengthDontMatch()
        public
    {
        tokens.push(address(0));
        priceFeeds.push(address(0));
        priceFeeds.push(address(0));
        StableCoin sc = new StableCoin();
        vm.startBroadcast(deployerKey);
        vm.expectRevert(
            SCEngine
                .SCEngine__TokenAddressesAndPriceFeedAddressesMustBeEqualLengths
                .selector
        );
        new SCEngine(tokens, priceFeeds, address(sc));
        vm.stopBroadcast();
    }

    /*
     * GIVEN: A user with enough collateral outside of engine
     * WHEN: User calls deposit collateral
     * THEN: Collateral is deposited
     */
    function test_canDepositCollateral()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
    {
        assertEq(scEngine.getCollateralValue(USER), 0);
        vm.startBroadcast(USER);
        scEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopBroadcast();
        assert(scEngine.getCollateralValue(USER) > 0);
    }

    /*
     * GIVEN: A user with less collateral as allowance that they try to deposit
     * WHEN: A user calls deposit collateral
     * THEN: Collateral is not deposited
     */
    function test_cantDepositCollateralInsufficientFunds()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
    {
        assertEq(scEngine.getCollateralValue(USER), 0);
        vm.startBroadcast(USER);
        vm.expectRevert();
        scEngine.depositCollateral(weth, COLLATERAL_AMOUNT * 10);
        vm.stopBroadcast();
        assertEq(scEngine.getCollateralValue(USER), 0);
    }

    /*
     * GIVEN: -
     * WHEN: User calls deposit with unallowed collateral
     * THEN: Collateral is not deposited (tx is reverted)
     */
    function test_cantDepositUnallowedCollateral() public {
        vm.startBroadcast(USER);
        vm.expectRevert(SCEngine.SCEngine__NotAllowedTokenCollateral.selector);
        scEngine.depositCollateral(address(0), COLLATERAL_AMOUNT);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: A user with enough collateral outside of engine
     * WHEN: A user calls deposit collateral
     * THEN: Zero can't be deposited
     */
    function test_cantDepositZero()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
    {
        assertEq(scEngine.getCollateralValue(USER), 0);
        vm.startBroadcast(USER);
        vm.expectRevert(SCEngine.SCEngine__MustBeMoreThanZero.selector);
        scEngine.depositCollateral(weth, 0);
        vm.stopBroadcast();
        assertEq(scEngine.getCollateralValue(USER), 0);
    }

    /*
     * GIVEN: A user with enough collateral deposited
     * WHEN: User calls mint with half the value of collateral
     * THEN: Can mint
     */
    function test_canMint()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
    {
        assert(scEngine.getCollateralValue(USER) > 0);
        vm.startBroadcast(USER);
        scEngine.mintSC(COLLATERAL_AMOUNT);
        vm.stopBroadcast();
        assert(scEngine.getCollateralValue(USER) > 0);
    }

    /*
     * GIVEN: A user with not enough collateral deposited
     * WHEN: User calls mint with half + 1 the value of collateral
     * THEN: Can mint
     */
    function test_cantMintAboveTwiceCollateral()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
    {
        assert(scEngine.getCollateralValue(USER) > 0);
        vm.startBroadcast(USER);
        vm.expectRevert(SCEngine.SCEngine__WouldBreakHealthFactor.selector);
        scEngine.mintSC((MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL) + 1);
        vm.stopBroadcast();
        assert(scEngine.getCollateralValue(USER) > 0);
    }

    /*
     * GIVEN: A user with enough collateral deposited
     * WHEN: User calls mint with 0
     * THEN: Can't mint 0
     */
    function test_cantMintZero()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
    {
        assert(scEngine.getCollateralValue(USER) > 0);
        vm.startBroadcast(USER);
        vm.expectRevert(SCEngine.SCEngine__MustBeMoreThanZero.selector);
        scEngine.mintSC(0);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: A user
     * WHEN: User calls deposit and mint
     * THEN: Can deposit and mint
     */
    function test_canDepositAndMint()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
    {
        vm.startBroadcast(USER);
        scEngine.mintSCWithCollateral(
            weth,
            COLLATERAL_AMOUNT,
            MINT_USD_VALUE_TO_MINT_WITH_ONE_COLLATERAL
        );
        vm.stopBroadcast();
        assertEq(
            scEngine.getSCBalance(USER),
            MINT_USD_VALUE_TO_MINT_WITH_ONE_COLLATERAL
        );
    }

    /*
     * GIVEN: A user with 1000 SC
     * WHEN: User calls burn with 1000 SC
     * THEN: All tokens are burned
     */
    function test_canBurnSC()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL)
    {
        vm.startBroadcast(USER);
        stableCoin.approve(
            address(scEngine),
            MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL
        );
        scEngine.burnSC(MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL);
        vm.stopBroadcast();
        assertEq(scEngine.getSCBalance(USER), 0);
    }

    /*
     * GIVEN: A user with 1000 SC
     * WHEN: User calls burn with 1000 SC without
     *       allowing SC for the engine to transfer
     * THEN: All tokens are burned
     */
    function test_cantBurnWithoutAllowance()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL)
    {
        vm.startBroadcast(USER);
        vm.expectRevert();
        scEngine.burnSC(MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL);
        vm.stopBroadcast();
        assertEq(
            scEngine.getSCBalance(USER),
            MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL
        );
    }

    /*
     * GIVEN: A user with 500 SC
     * WHEN: User redeems 500 USD value of collateral with 1500 USD remaining
     * THEN: Tokens were redeemed and total USD collateral value is 1500
     */
    function test_canRedeemCollateral()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL / 2)
    {
        vm.startBroadcast(USER);

        scEngine.redeemCollateral(weth, COLLATERAL_AMOUNT / 2);
        vm.stopBroadcast();
        assertEq(
            scEngine.getCollateralValue(USER),
            DEPOSITED_USD_VALUE - (DEPOSITED_USD_VALUE / 4)
        );
    }

    /*
     * GIVEN: A user with 1000 SC
     * WHEN: User redeems 1000 USD value of collateral with 1000 USD remaining
     * THEN: Tokens are not redeemed as it would break health factor
     */
    function test_cantRedeemCollateralIfBreaksHealthFactor()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL)
    {
        vm.startBroadcast(USER);
        vm.expectRevert(SCEngine.SCEngine__WouldBreakHealthFactor.selector);
        scEngine.redeemCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopBroadcast();
        assertEq(scEngine.getCollateralValue(USER), DEPOSITED_USD_VALUE);
    }

    /*
     * GIVEN: A user with 1000 SC
     * WHEN: User redeems 0 USD value of collateral with 2000 USD remaining
     * THEN: Transaction is reverted
     */
    function test_cantRedeemZeroCollateral()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL)
    {
        vm.startBroadcast(USER);
        vm.expectRevert(SCEngine.SCEngine__MustBeMoreThanZero.selector);
        scEngine.redeemCollateral(weth, 0);
        vm.stopBroadcast();
        assertEq(scEngine.getCollateralValue(USER), DEPOSITED_USD_VALUE);
    }

    /*
     * GIVEN: A user with 1000 SC
     * WHEN: User burns 500 USD worth of SC and redeems 1000 USD
     *       value of collateral with 1000 USD remaining
     * THEN: User can reedem collateral
     */
    function test_canRedeemCollateralForSC()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL)
    {
        uint256 toBurn = MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL / 2;
        vm.startBroadcast(USER);
        stableCoin.approve(address(scEngine), toBurn);
        scEngine.redeemCollateralForSC(toBurn, weth, COLLATERAL_AMOUNT);
        vm.stopBroadcast();
        assertEq(scEngine.getCollateralValue(USER), DEPOSITED_USD_VALUE / 2);
        assertEq(
            scEngine.getSCBalance(USER),
            MINT_USD_VALUE_TO_MINT_WITH_ONE_COLLATERAL
        );
    }

    /*
     * GIVEN: A user with 1000 SC
     * WHEN: User burns 1 USD worth of SC and redeems 1000 USD
     *       value of collateral with 1000 USD remaining
     * THEN: Transaction is reverted and balances are unchanged
     */
    function test_cantRedeemCollateralForSCIfWouldBreakHealthFactor()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL)
    {
        uint256 toBurn = 1;
        vm.startBroadcast(USER);
        stableCoin.approve(address(scEngine), toBurn);
        vm.expectRevert(SCEngine.SCEngine__WouldBreakHealthFactor.selector);
        scEngine.redeemCollateralForSC(toBurn, weth, COLLATERAL_AMOUNT);
        vm.stopBroadcast();
        assertEq(scEngine.getCollateralValue(USER), DEPOSITED_USD_VALUE);
        assertEq(
            scEngine.getSCBalance(USER),
            MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL
        );
    }

    /*
     * GIVEN: A healthy user
     * WHEN: Someone calls liquidate on the user
     * THEN: User is not liquidated (tx is reverted)
     */
    function test_cantLiquidateHealthyUser() public {
        vm.startBroadcast(USER);
        vm.expectRevert(SCEngine.SCEngine__HealthFactorOk.selector);
        scEngine.liquidate(weth, USER, 1 ether);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: A user with 2000 dollar worth of collateral and 1000 SC
     * WHEN: Healt factor is queried
     * THEN: Health factor is max
     */
    function test_minHealthyHealthFactor()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL)
    {
        vm.startBroadcast(USER);
        assertEq(scEngine.getHealthFactor(USER), 1e18);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: A user with 2000 dollar worth of collateral and 1001 SC
     * WHEN: Healt factor is queried
     * THEN: Health factor is max
     */
    function justBelowMinHealthyHealthFactor()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, (MINT_USD_VALUE_TO_MINT_WITH_TWO_COLLATERAL) + 1)
    {
        // TODO this cannot be tested as of now. Think how to decouple if it makes sense from minting itself.
        vm.startBroadcast(USER);
        assertEq(scEngine.getHealthFactor(USER), 1e18);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: A user with 2000 dollar worth of collateral and no SC
     * WHEN: Healt factor is queried
     * THEN: Health factor is max
     */
    function test_maxHealthFactor()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
    {
        vm.startBroadcast(USER);
        assertEq(scEngine.getHealthFactor(USER), type(uint256).max);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: A pricefeed with 1 eth = 1000 usd
     * WHEN: We query the usd value of 1 eth
     * THEN: We get 1000 usd
     */
    function test_getUsdValue() public {
        assertEq(scEngine.getUsdValue(weth, 1 ether), 1000 ether);
    }

    function test_getAccountInformationZero()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, MINT_USD_VALUE_TO_MINT_WITH_ONE_COLLATERAL)
    {
        (uint256 totalSCMinted, uint256 totalCollateralValue) = scEngine
            .getAccountInformation(USER);
        assertEq(totalSCMinted, MINT_USD_VALUE_TO_MINT_WITH_ONE_COLLATERAL);
        assertEq(totalCollateralValue, DEPOSITED_USD_VALUE);
    }

    modifier mintCollateralForUser(address user) {
        vm.startBroadcast(deployerKey);
        ERC20Mock(weth).mint(user, COLLATERAL_AMOUNT);
        ERC20Mock(wbtc).mint(user, COLLATERAL_AMOUNT);
        vm.stopBroadcast();
        _;
    }

    modifier allowEngineForCollateral(address user, uint256 amount) {
        vm.startBroadcast(user);
        ERC20Mock(weth).approve(address(scEngine), amount);
        ERC20Mock(wbtc).approve(address(scEngine), amount);
        vm.stopBroadcast();
        _;
    }

    modifier depositCollateral(address user, uint256 amount) {
        vm.startBroadcast(user);
        scEngine.depositCollateral(weth, amount);
        scEngine.depositCollateral(wbtc, amount);
        uint256 collateralValue = scEngine.getCollateralValue(user);
        // TODO this wont work on other networks but the local mock env
        assertEq(collateralValue, DEPOSITED_USD_VALUE);
        vm.stopBroadcast();
        _;
    }

    modifier mintSC(address user, uint256 amount) {
        vm.startBroadcast(user);
        scEngine.mintSC(amount);
        assertEq(scEngine.getSCBalance(user), amount);
        vm.stopBroadcast();
        _;
    }
}

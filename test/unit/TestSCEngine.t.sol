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

    address constant USER = address(1337);
    uint256 constant COLLATERAL_AMOUNT = 1e18;
    uint256 constant DEPOSITED_USD_VALUE = 2e21; // 2000 USD

    function setUp() external {
        DeploySCEngine deploySCEngine = new DeploySCEngine();
        (scEngine, config) = deploySCEngine.run();
        (, , weth, wbtc, deployerKey) = config.activeNetworkConfig();
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
        assert(scEngine.getCollateralValue(USER) == 0);
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
        assert(scEngine.getCollateralValue(USER) == 0);
        vm.startBroadcast(USER);
        vm.expectRevert();
        scEngine.depositCollateral(weth, COLLATERAL_AMOUNT * 10);
        vm.stopBroadcast();
        assert(scEngine.getCollateralValue(USER) == 0);
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
        assert(scEngine.getCollateralValue(USER) == 0);
        vm.startBroadcast(USER);
        vm.expectRevert(SCEngine.SCEngine__MustBeMoreThanZero.selector);
        scEngine.depositCollateral(weth, 0);
        vm.stopBroadcast();
        assert(scEngine.getCollateralValue(USER) == 0);
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
        vm.expectRevert(SCEngine.SCEngine__NotEnoughCollateral.selector);
        scEngine.mintSC((DEPOSITED_USD_VALUE / 2) + 1);
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
     * GIVEN: A user with 2000 dollar worth of collateral and 1000 SC
     * WHEN: Healt factor is queried
     * THEN: Health factor is max
     */
    function test_minHealthyHealthFactor()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, DEPOSITED_USD_VALUE / 2)
    {
        vm.startBroadcast(USER);
        assert(scEngine.getHealthFactor(USER) == 1e18);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: A user with 2000 dollar worth of collateral and 1001 SC
     * WHEN: Healt factor is queried
     * THEN: Health factor is max
     */
    function test_justBelowMinHealthyHealthFactor()
        public
        mintCollateralForUser(USER)
        allowEngineForCollateral(USER, COLLATERAL_AMOUNT)
        depositCollateral(USER, COLLATERAL_AMOUNT)
        mintSC(USER, (DEPOSITED_USD_VALUE / 2) + 1)
    {
        // TODO this cannot be tested as of now. Think how to decouple if it makes sense from minting itself.
        vm.startBroadcast(USER);
        assert(scEngine.getHealthFactor(USER) == 1e18);
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
        assert(scEngine.getHealthFactor(USER) == type(uint256).max);
        vm.stopBroadcast();
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
        console.log(collateralValue);
        assert(collateralValue == DEPOSITED_USD_VALUE);
        vm.stopBroadcast();
        _;
    }

    modifier mintSC(address user, uint256 amount) {
        vm.startBroadcast(user);
        scEngine.mintSC(amount);
        vm.stopBroadcast();
        _;
    }
}

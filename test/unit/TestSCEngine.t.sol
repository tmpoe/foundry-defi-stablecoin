// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {Config} from "../../script/Config.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {DeploySCEngine} from "../../script/DeploySCEngine.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestSCEngine is Test {
    Config config;
    uint256 deployerKey;
    SCEngine scEngine;
    address weth;
    address wbtc;

    address constant USER = address(1337);

    function setUp() external {
        DeploySCEngine deploySCEngine = new DeploySCEngine();
        (scEngine, config) = deploySCEngine.run();
        (, , weth, wbtc, deployerKey) = config.activeNetworkConfig();
    }

    /*
     * GIVEN: A stable coin engine
     * WHEN: A user calls deposit collateral
     * THEN: Collateral is deposited
     */
    function test_canDepositCollateral() public mintCollateralForUser(USER) {
        assert(scEngine.getCollateralValue(USER) == 0);
        vm.startBroadcast(USER);
        ERC20Mock(weth).approve(address(scEngine), 10000000000000000);
        scEngine.depositCollateral(weth, 10000000000000000);
        vm.stopBroadcast();
        assert(scEngine.getCollateralValue(USER) > 0);
    }

    modifier mintCollateralForUser(address user) {
        vm.startBroadcast(deployerKey);
        ERC20Mock(weth).mint(user, 1000000000000000000);
        ERC20Mock(wbtc).mint(user, 1000000000000000000);
        vm.stopBroadcast();
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {Config} from "../../script/Config.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";

contract TestStableCoin is Test {
    Config config;
    StableCoin stableCoin;
    uint256 deployerKey;

    function setUp() external {
        DeployStableCoin deployStableCoin = new DeployStableCoin();
        (stableCoin, config) = deployStableCoin.run();
        (, , , , deployerKey) = config.activeNetworkConfig();
    }

    /*
     * GIVEN: A stable coin contract
     * WHEN: We call mint for a user
     * THEN: We can mint for that user
     */
    function test_canMint() public {
        vm.startBroadcast(deployerKey);
        stableCoin.mint(address(this), 1000000000000000000);
        vm.stopBroadcast();
        assert(stableCoin.balanceOf(address(this)) == 1000000000000000000);
    }

    /*
     * GIVEN: A stable coin contract
     * WHEN: We call mint for address zero
     * THEN: We can't mint for that address
     */
    function test_cantMintForZeroAddress() public {
        vm.startBroadcast(deployerKey);
        vm.expectRevert(StableCoin.StableCoin__ZeroAddress.selector);
        stableCoin.mint(address(0), 1000000000000000000);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: A stable coin contract
     * WHEN: We call mint for a user with zero amount
     * THEN: We can't mint a zero amount
     */
    function test_cantMintNegativeAmount() public {
        vm.startBroadcast(deployerKey);
        vm.expectRevert(StableCoin.StableCoin__MustBeMoreThanZero.selector);
        stableCoin.mint(address(this), 0);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: Some stable coins
     * WHEN: Call burn with amount X
     * THEN: We can burn X amount of coins
     */
    function test_canBurn() public setupUser {
        vm.startBroadcast(deployerKey);
        stableCoin.burn(100000000000000000);
        vm.stopBroadcast();
        assert(stableCoin.balanceOf(stableCoin.owner()) == 900000000000000000);
    }

    /*
     * GIVEN: Some stable coins
     * WHEN: Call burn with amount 0
     * THEN: We can't burn 0 amount of coins
     */
    function test_cantBurnZero() public setupUser {
        vm.startBroadcast(deployerKey);
        vm.expectRevert(StableCoin.StableCoin__MustBeMoreThanZero.selector);
        stableCoin.burn(0);
        vm.stopBroadcast();
    }

    /*
     * GIVEN: Some stable coins
     * WHEN: Call burn for with more than we have
     * THEN: We can't burn more than we have
     */
    function test_cantBurnMoreThanWeHave() public setupUser {
        vm.startBroadcast(deployerKey);
        vm.expectRevert(
            StableCoin.StableCoin__BurnAmountIsMoreThanBalance.selector
        );
        stableCoin.burn(1000000000000000001);
        vm.stopBroadcast();
    }

    modifier setupUser() {
        vm.startBroadcast(deployerKey);
        stableCoin.mint(address(stableCoin.owner()), 1000000000000000000);
        vm.stopBroadcast();
        _;
    }
}

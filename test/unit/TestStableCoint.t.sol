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
        deployerKey = config.activeNetworkConfig();
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
     * GIVEN: A user with a balance
     * WHEN: A user for whom we want to burn
     * THEN: We can burn for that user
     */
    function test_canBurn() public setupUser {
        vm.startBroadcast(deployerKey);
        stableCoin.burn(100000000000000000);
        vm.stopBroadcast();
        assert(stableCoin.balanceOf(stableCoin.owner()) == 900000000000000000);
    }

    modifier setupUser() {
        vm.startBroadcast(deployerKey);
        stableCoin.mint(address(stableCoin.owner()), 1000000000000000000);
        vm.stopBroadcast();
        _;
    }
}

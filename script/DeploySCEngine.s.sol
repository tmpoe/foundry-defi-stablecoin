// SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {StableCoin} from "../src/StableCoin.sol";
import {SCEngine} from "../src/SCEngine.sol";
import {Config} from "./Config.sol";

contract DeploySCEngine is Script {
    address[] public tokens;
    address[] public priceFeeds;

    function run() external returns (SCEngine, Config) {
        Config config = new Config();
        (
            address wethPriceFeed,
            address bethPricefeed,
            address weth,
            address beth,
            uint256 deployerKey
        ) = config.activeNetworkConfig();

        priceFeeds = [wethPriceFeed, bethPricefeed];
        tokens = [weth, beth];
        vm.startBroadcast(deployerKey);
        console.log("Deploying StableCoin");
        StableCoin stableCoin = new StableCoin();
        console.log("StableCoin deployed to ", address(stableCoin));
        console.log("Deploying SCEngine");
        SCEngine scEngine = new SCEngine(
            tokens,
            priceFeeds,
            address(stableCoin)
        );
        console.log("SCEngine deployed to ", address(scEngine));
        stableCoin.transferOwnership(address(scEngine));
        console.log(
            "Post tranfserOwner StableCoin owner is ",
            stableCoin.owner()
        );
        vm.stopBroadcast();
        return (scEngine, config);
    }
}

// SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
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
        StableCoin stableCoin = new StableCoin();
        SCEngine scEngine = new SCEngine(
            tokens,
            priceFeeds,
            address(stableCoin)
        );
        vm.stopBroadcast();
        return (scEngine, config);
    }
}

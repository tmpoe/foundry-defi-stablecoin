// SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {StableCoin} from "../src/StableCoin.sol";
import {Config} from "./Config.sol";

contract DeployStableCoin is Script {
    function run() external returns (StableCoin, Config) {
        Config config = new Config();
        (,,,, uint256 deployerKey) = config.activeNetworkConfig();
        vm.startBroadcast(deployerKey);
        StableCoin stableCoin = new StableCoin();
        vm.stopBroadcast();
        return (stableCoin, config);
    }
}

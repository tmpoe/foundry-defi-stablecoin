// SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {StableCoin} from "../src/StableCoin.sol";

contract DeployStableCoin is Script {
    function run() external returns (StableCoin) {
        vm.startBroadcast();
        StableCoin stableCoin = new StableCoin();
        vm.stopBroadcast();
        return stableCoin;
    }
}

// SPDX-License-Identifier: MIT

// What are my system invariants?

// 1. DSC supply should be less then the total value of collateral

// 2. Getters should never revert

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StableCoin} from "../../src/StableCoin.sol";
import {Config} from "../../script/Config.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {DeploySCEngine} from "../../script/DeploySCEngine.s.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    Config config;
    uint256 deployerKey;
    SCEngine scEngine;
    address weth;
    address wbtc;
    address wethPriceFeed;
    address wbtcPriceFeed;
    StableCoin stableCoin;
    Handler handler;

    function setUp() external {
        DeploySCEngine deploySCEngine = new DeploySCEngine();
        (scEngine, config) = deploySCEngine.run();
        (wethPriceFeed, wbtcPriceFeed, weth, wbtc, deployerKey) = config
            .activeNetworkConfig();
        stableCoin = StableCoin(scEngine.getStableCoinAddress());
        handler = new Handler(scEngine, stableCoin);
        // this tells the test contract to go wild with our contract
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = stableCoin.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(scEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(scEngine));

        uint256 wethValue = scEngine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = scEngine.getUsdValue(wbtc, totalWbtcDeposited);

        assert(wethValue + wbtcValue >= totalSupply);
    }
}

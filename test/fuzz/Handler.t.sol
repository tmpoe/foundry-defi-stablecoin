// SPDX-License-Identifier: MIT

// More or less handles the order or preconditions for function calls

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {SCEngine} from "../../src/SCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";

contract Handler is Test {
    SCEngine scEngine;
    StableCoin stableCoin;
    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT = type(uint96).max;

    constructor(SCEngine _scEngine, StableCoin _stableCoin) {
        scEngine = _scEngine;
        stableCoin = _stableCoin;

        address[] memory collateralAddresses = scEngine
            .getCollateralAddresses();
        weth = ERC20Mock(collateralAddresses[0]);
        wbtc = ERC20Mock(collateralAddresses[1]);
    }

    function depositCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(scEngine), amountCollateral);
        scEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function _getCollateralFromSeed(
        uint256 seed
    ) internal view returns (ERC20Mock) {
        if (seed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}

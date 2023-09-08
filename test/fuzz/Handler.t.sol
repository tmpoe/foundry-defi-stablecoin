// SPDX-License-Identifier: MIT

// More or less handles the order or preconditions for function calls

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {SCEngine} from "../../src/SCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";

contract Handler is Test {
    SCEngine scEngine;
    StableCoin stableCoin;
    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT = type(uint96).max;
    address[] public addressesWithCollateralDeposited;

    constructor(SCEngine _scEngine, StableCoin _stableCoin) {
        scEngine = _scEngine;
        stableCoin = _stableCoin;

        address[] memory collateralAddresses = scEngine
            .getCollateralAddresses();
        weth = ERC20Mock(collateralAddresses[0]);
        wbtc = ERC20Mock(collateralAddresses[1]);
    }

    function mint(uint256 amount, uint256 addressSeed) public {
        if (addressesWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = addressesWithCollateralDeposited[
            addressSeed % addressesWithCollateralDeposited.length
        ];
        (uint256 totalSCMinted, uint256 totalCollateralValueInUSD) = scEngine
            .getAccountInformation(sender);

        int256 maxAmountToMint = (int256(totalCollateralValueInUSD) / 2) -
            int256(totalSCMinted);

        amount = bound(amount, 0, uint256(maxAmountToMint));
        console.log("amount: %s", amount);
        if (amount == 0) {
            return;
        }

        vm.startPrank(sender);
        scEngine.mintSC(amount);
        vm.stopPrank();
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
        addressesWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = scEngine.getUserCollateralBalance(
            address(collateral),
            msg.sender
        );
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        scEngine.redeemCollateral(address(collateral), amountCollateral);
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

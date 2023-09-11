// SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library Oracle {
    error Oracle__PriceFeedIsStale();
    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckedLatestRoundData(
        AggregatorV3Interface priceFeed
    )
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed
            .latestRoundData();
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) {
            revert Oracle__PriceFeedIsStale();
        }
    }
}

// SPDX-License-Identifier: MIT

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.28;
import {MockV3Aggregator as _MockV3Aggregator} from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

contract MockV3Aggregator is _MockV3Aggregator {
    constructor(
        uint8 _decimals,
        int256 _initialAnswer
    ) _MockV3Aggregator(_decimals, _initialAnswer) {}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {TokenAsset} from "./TokenAsset.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {MockFunctionsRouter} from "./mocks/MockFunctionsRouter.sol";
import {Test} from "forge-std/Test.sol";

contract TokenAssetTest is Test {
    TokenAsset tokenAsset;

    function setUp() public {
        MockV3Aggregator mockAggregator = new MockV3Aggregator(8, 465078544578);
        MockFunctionsRouter mockRouter = new MockFunctionsRouter();
        tokenAsset = new TokenAsset(
            "ipfs://",
            address(mockAggregator),
            'return Functions.encodeString("ok");',
            address(mockRouter),
            "0x",
            0,
            "0x123"
        );
    }

    function test_InitialValue() public view {
        require(
            tokenAsset.nextTokenId() == 0,
            "Initial nextTokenId should be 0"
        );
    }

    function testFuzz_Create() public {
        tokenAsset.deploy(100, 200, "ipfs://");
        tokenAsset.deploy(200, 300, "ipfs://");
        require(
            tokenAsset.nextTokenId() == 2,
            "Value after 2 deploys should be 2"
        );
    }

    function test_zeroQty() public {
        vm.expectRevert();
        tokenAsset.deploy(0, 200, "ipfs://");
    }

    function test_mint() public {
        tokenAsset.deploy(100, 200, "ipfs://");
        (uint256 amount, uint80 roundId, ) = tokenAsset.getQuote(0);
        tokenAsset.mint{value: amount}(0, 1, roundId);
    }
}

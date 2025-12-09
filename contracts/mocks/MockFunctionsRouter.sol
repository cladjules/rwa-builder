// SPDX-License-Identifier: MIT

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.28;

import {IFunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsRouter.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsResponse.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_3_0/FunctionsClient.sol";

contract MockFunctionsRouter is IFunctionsRouter {
    address private client;

    function sendRequest(
        uint64 /* subscriptionId */,
        bytes calldata /* data */,
        uint16 /* dataVersion */,
        uint32 /* callbackGasLimit */,
        bytes32 /* donId */
    ) external returns (bytes32) {
        client = msg.sender;
        return "32";
    }

    function getAllowListId() external view override returns (bytes32) {}

    function setAllowListId(bytes32 allowListId) external override {}

    function getAdminFee() external view override returns (uint72 adminFee) {}

    function sendRequestToProposed(
        uint64 /* subscriptionId */,
        bytes calldata /* data */,
        uint16 /* dataVersion */,
        uint32 /* callbackGasLimit */,
        bytes32 /* donId */
    ) external pure override returns (bytes32) {
        return "32";
    }

    function fulfill(
        bytes memory /* response */,
        bytes memory /* err */,
        uint96 /* juelsPerGas */,
        uint96 /* costWithoutFulfillment */,
        address /* transmitter */,
        FunctionsResponse.Commitment memory /* commitment */
    ) external pure override returns (FunctionsResponse.FulfillResult, uint96) {
        return (FunctionsResponse.FulfillResult.FULFILLED, 0);
    }

    function mockFulfill() external {
        FunctionsClient(client).handleOracleFulfillment(
            "32",
            abi.encodePacked("1000000000000000000"),
            ""
        );
    }

    function isValidCallbackGasLimit(
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) external view override {}

    function getContractById(
        bytes32 id
    ) external view override returns (address) {}

    function getProposedContractById(
        bytes32 id
    ) external view override returns (address) {}

    function getProposedContractSet()
        external
        view
        override
        returns (bytes32[] memory, address[] memory)
    {}

    function proposeContractsUpdate(
        bytes32[] memory proposalSetIds,
        address[] memory proposalSetAddresses
    ) external override {}

    function updateContracts() external override {}

    function pause() external override {}

    function unpause() external override {}
}

import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { FN_UPDATE_JS } from "../ignition/modules/TokenAsset.js";

const DonId =
  "0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000";

describe("TokenAsset", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();

  const setUp = async function () {
    const mockV3Aggregator = await viem.deployContract("MockV3Aggregator", [
      8,
      465078544578n,
    ]);
    const mockFunctionsRouter = await viem.deployContract(
      "MockFunctionsRouter"
    );

    const tokenAsset = await viem.deployContract("TokenAsset", [
      "ipfs://",
      mockV3Aggregator.address,
      FN_UPDATE_JS,
      mockFunctionsRouter.address,
      DonId,
      0n,
      "0x123",
    ]);

    return { tokenAsset, mockFunctionsRouter };
  };

  it("Should emit the Deployed event when calling the deploy() function", async function () {
    const { tokenAsset } = await setUp();

    await viem.assertions.emitWithArgs(
      tokenAsset.write.deploy([1000n, 1000n, "ipfs://"]),
      tokenAsset,
      "Deployed",
      [0n]
    );
  });

  it("The sum of the Deployed events should match the current value", async function () {
    const { tokenAsset } = await setUp();

    const deploymentBlockNumber = await publicClient.getBlockNumber();

    // run a series of increments
    for (let i = 1n; i <= 10n; i++) {
      await tokenAsset.write.deploy([1000n, 1000n, "ipfs://"]);
    }

    const events = await publicClient.getContractEvents({
      address: tokenAsset.address,
      abi: tokenAsset.abi,
      eventName: "Deployed",
      fromBlock: deploymentBlockNumber,
      strict: true,
    });

    // check that the aggregated events match the current value
    let id = 0n;
    for (const event of events) {
      id = event.args.id;
    }

    assert.equal(id, (await tokenAsset.read.nextTokenId()) - 1n);
  });

  it("When minting, values should match", async function () {
    const { tokenAsset, mockFunctionsRouter } = await setUp();

    const [acc1] = await viem.getWalletClients();

    const deploymentBlockNumber = await publicClient.getBlockNumber();

    const quantityToMint = 3n;

    // run a series of increments
    await tokenAsset.write.deploy([1000n, 1000n, "ipfs://"]);

    const [quote, roundId] = await tokenAsset.read.getQuote([0n]);

    await tokenAsset.write.mint([0n, quantityToMint, roundId], {
      value: quote * quantityToMint,
    });

    await mockFunctionsRouter.write.mockFulfill();

    assert.equal(
      await tokenAsset.read.balanceOf([acc1.account.address, 0n]),
      quantityToMint
    );

    const events = await publicClient.getContractEvents({
      address: tokenAsset.address,
      abi: tokenAsset.abi,
      eventName: "MintSuccess",
      fromBlock: deploymentBlockNumber,
      strict: true,
    });

    assert.equal(events[0].args.quantity, quantityToMint);
    assert.equal(events[0].args.id, 0n);

    // The contract has received the quote
    assert.equal(
      await publicClient.getBalance(tokenAsset),
      quote * quantityToMint
    );
  });

  it("When withdrawing, values should match", async function () {
    const { tokenAsset, mockFunctionsRouter } = await setUp();

    const [acc1] = await viem.getWalletClients();

    const deploymentBlockNumber = await publicClient.getBlockNumber();

    const quantityToMint = 3n;
    const quantityToWithdraw = 2n;

    // run a series of increments
    await tokenAsset.write.deploy([1000n, 1000n, "ipfs://"]);
    await tokenAsset.write.deploy([200n, 200n, "ipfs://"]);

    const [quote, roundId] = await tokenAsset.read.getQuote([1n]);

    await tokenAsset.write.mint([1n, quantityToMint, roundId], {
      value: quote * quantityToMint,
    });

    await mockFunctionsRouter.write.mockFulfill();

    await tokenAsset.write.withdraw([1n, quantityToWithdraw]);

    await mockFunctionsRouter.write.mockFulfill();

    assert.equal(
      await tokenAsset.read.balanceOf([acc1.account.address, 1n]),
      quantityToMint - quantityToWithdraw
    );

    const events = await publicClient.getContractEvents({
      address: tokenAsset.address,
      abi: tokenAsset.abi,
      eventName: "WithdrawSuccess",
      fromBlock: deploymentBlockNumber,
      strict: true,
    });

    assert.equal(events[0].args.quantity, quantityToWithdraw);
    assert.equal(events[0].args.id, 1n);

    // The contract has received the quote
    assert.equal(
      await publicClient.getBalance(tokenAsset),
      quote * (quantityToMint - quantityToWithdraw)
    );
  });
});

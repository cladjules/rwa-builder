import { SecretsManager } from "@chainlink/functions-toolkit";
import { ethers, AlchemyProvider } from "ethers";

// TODO: Support multiple networks
// Right now only Base Sepolia is supported

export const getNetworkVars = async () => {
  // hardcoded for Base Sepolia
  const routerAddress = "0xf9B8fc078197181C841c296C876945aaa425B278";
  const donId = "fun-base-sepolia-1";
  const gatewayUrls = [
    "https://01.functions-gateway.testnet.chain.link/",
    "https://02.functions-gateway.testnet.chain.link/",
  ];
  const alchemyNetworkName = "base-sepolia";

  // Initialize ethers signer and provider to interact with the contracts onchain
  const privateKey = process.env.TESTNET_PRIVATE_KEY;
  if (!privateKey)
    throw new Error(
      "private key not provided - check your environment variables"
    );

  if (!process.env.ALCHEMY_API_KEY)
    throw new Error(
      `Alchemy key not provided  - check your environment variables`
    );

  const provider = new AlchemyProvider(
    alchemyNetworkName,
    process.env.ALCHEMY_API_KEY
  );

  const signer = new ethers.Wallet(privateKey, provider);

  // Add v5 compatibility for functions-toolkit
  // @ts-expect-error - v5 compatibility
  signer._isSigner = true;
  // @ts-expect-error - v5 compatibility
  signer.getChainId = async () => {
    const network = await provider.getNetwork();
    return Number(network.chainId);
  };

  // First encrypt secrets and upload the encrypted secrets to the DON
  const secretsManager = new SecretsManager({
    // @ts-expect-error - v5 compatibility
    signer,
    functionsRouterAddress: routerAddress,
    donId,
  });

  await secretsManager.initialize();

  return { secretsManager, signer, gatewayUrls };
};

import fs from "fs";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// TODO: Move to another file and use proper DON-hosted secrets
export const FN_UPDATE_JS: string = `const id = Number(args[0]) + 1;
  const quantity = args[1];
  const to = args[2];
  const hash = args[3];
  const secret = secrets.apiSecret;
  const apiResponse = await Functions.makeHttpRequest({
    url: \`${process.env.CONTRACT_FN_UPDATE_API_URL}\`
  }); 
  if (apiResponse.error) {
    throw Error('Request failed');
  }
  const { data } = apiResponse;
  return Functions.encodeString(data.message);`;

// Values for Base Sepolia, add more for other networks as needed
// https://docs.chain.link/chainlink-functions/supported-networks
const FN_DON_ID =
  "0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000";
export const FN_ROUTER = "0xf9B8fc078197181C841c296C876945aaa425B278";

// Feeds for Base Sepolia, add more for other networks as needed
// https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&testnetPage=1
const FEED_ETH_USD = "0x4adc67696ba383f43dd60a9e78f2c97fbbfc7cb1";

export default buildModule("TokenAssetModule", (m) => {
  const encryptedSecretURLs = fs.readFileSync(
    "./.secrets-upload-result.txt",
    "utf-8"
  );

  const tokenAsset = m.contract("TokenAsset", [
    "ipfs://",
    FEED_ETH_USD,
    FN_UPDATE_JS,
    FN_ROUTER,
    FN_DON_ID,
    process.env.FN_SUB_ID!,
    encryptedSecretURLs,
  ]);

  const prices = [15, 22, 28, 35, 42, 12, 48, 18, 32, 50];

  for (let i = 0; i < 10; i++) {
    console.log("Deploying TokenAsset #", i);
    m.call(tokenAsset, "deploy", [500, prices[i], ""], { id: `deploy_${i}` });
  }

  return { tokenAsset };
});

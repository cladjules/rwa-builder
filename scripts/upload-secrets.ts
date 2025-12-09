import fs from "fs";
import { getNetworkVars } from "./utils.js";

// TODO: Support multiple networks
// Right now only Base Sepolia is supported

const uploadSecrets = async () => {
  if (!process.env.GIST_URL)
    throw new Error(
      `GIST_URL not provided  - check your environment variables`
    );

  const { secretsManager, gatewayUrls } = await getNetworkVars();

  // Encrypt secrets from Gist, create them here https://gist.github.com and set the GIST_URL env variable
  // it should be the JSON file .secrets-create.json created from the create-secrets.ts script
  // make sure it has /raw at the end of the URL to get the raw file content
  const encryptedSecretRes = await secretsManager.encryptSecretsUrls([
    process.env.GIST_URL!,
  ]);

  console.log(`Upload encrypted secret to gateways ${gatewayUrls}.`);

  fs.writeFileSync("./.secrets-upload-result.txt", encryptedSecretRes);
};

uploadSecrets().catch((e) => {
  console.error(e);
  process.exit(1);
});

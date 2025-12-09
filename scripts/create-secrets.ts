import fs from "fs";
import { getNetworkVars } from "./utils.js";

const createSecrets = async () => {
  if (!process.env.CONTRACT_FN_API_SECRET)
    throw new Error(
      `CONTRACT_FN_API_SECRET not provided  - check your environment variables`
    );

  const { secretsManager } = await getNetworkVars();

  const encryptedSecretRes = await secretsManager.encryptSecrets({
    apiSecret: process.env.CONTRACT_FN_API_SECRET,
  });

  console.log(`Create encrypted secrets.`);

  fs.writeFileSync(
    "./.secrets-create.json",
    JSON.stringify(encryptedSecretRes)
  );
};

createSecrets().catch((e) => {
  console.error(e);
  process.exit(1);
});

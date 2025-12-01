# rwa-builder

This project is a POC of building RWA contracts using ChainLink Functions and Data Feeds (Oracle)

It highlights how to fetch an on-chain price feed (ETH/USD in that case), allow payment in ETH from a price in USD.

And lets you call an off-chain API to purchase the asset and update a database so it can be updated on your application
and the balance between ERC-1155 and the database is always synced.

## Notes

The smart contracts are not optimized for gas or audited. Use at your own risk.

You can see a demo here https://rwa.cladjules.com/

## Development

The product is built and tested with Hardhat 3

The only environment setup and tested for is Base Sepolia

## Environment

Setup a `.env` file with:

```
CONTRACT_FN_MINT_API_URL=https://xxxx.com/api-update?id=${id}&quantity=${quantity}&to=${to}&hash=${hash}
ALCHEMY_API_KEY=""
TESTNET_PRIVATE_KEY=""
EXPLORER_API_KEY=""
FN_SUB_ID=xx
```

You will need to setup a chainlink function on https://functions.chain.link/base-sepolia
and get your own subscriptionId to set the env `FN_SUB_ID`

## Deploy contracts

You can call `deploy:baseSepolia` in order to deploy on Base Sepolia

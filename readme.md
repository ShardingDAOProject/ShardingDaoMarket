## NFT contract
###  deploy
1. Download the dependence
```
npm install openzeppelin-solidity
npm install truffle-hdwallet-provider
npm install dotenv
``` 
2. Add the. Env file in the contract root directory, and add the environment variable in the. Env file for deployment account configuration
``` 
mnemonic_kovan = "the private key";
```

3. deploy
```
truffle migrate --network kovan
```
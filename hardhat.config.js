/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config()

module.exports = {
  solidity: "0.8.19",
  networks: {
    hardhat: {
      forking: {
        url: "https://eth.llamarpc.com"
      }
    },
    goerli:{
      url:"https://eth-goerli.public.blastapi.io\t",
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  etherscan:{
    apiKey: "VZ78U22G3ED27ZBQZ2E2TA7U5CUHMDJI81"
  },
  localhost: {
    url: "http://127.0.0.1:8545"
  }
}

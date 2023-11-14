/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config()

module.exports = {
  solidity: "0.8.19",
  networks: {
    hardhat: {
      forking: {
        url: "https://eth.llamarpc.com",
        blockNumber: 18567741 //This block is selected because in the next block a user claims its
                              //funds, and we want to do it before he/she do it. So should not be changed to
                              //further blockNumber
      }
    },
    goerli:{
      url:"https://eth-goerli.public.blastapi.io",
      accounts: [process.env.GOERLI_PRIVATE_KEY]
    },
    mainnet: {
      url: "https://eth.llamarpc.com",
      accounts: [process.env.MAIN_NET_PRIVATE_KEY]
    }
  },
  etherscan:{
    apiKey: "VZ78U22G3ED27ZBQZ2E2TA7U5CUHMDJI81"
  },
  localhost: {
    url: "http://127.0.0.1:8545"
  }
}

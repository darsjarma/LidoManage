/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");
module.exports = {
  solidity: "0.8.19",
  networks: {
    hardhat: {
      forking: {
        url: "https://eth.llamarpc.com"
      }
    }
  },
  localhost: {
    url: "http://127.0.0.1:8545"
  }
}

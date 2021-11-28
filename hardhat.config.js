require("@nomiclabs/hardhat-waffle");
require("dotenv").config();
require("@nomiclabs/hardhat-etherscan");

const pk = process.env.PRIVATE_KEY; 
const endpoint = process.env.KOVAN_RPC_URL;
const etherscanKey = process.env.ETHERSCAN_API_KEY;

module.exports = {
  solidity: "0.8.7",
  networks: {
    kovan: {
      url:endpoint,
      accounts:[`0x${pk}`]
    },
  },
    etherscan: {
      // Your API key for Etherscan
      // Obtain one at https://etherscan.io/
      apiKey:etherscanKey
    }
  
};
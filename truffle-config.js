const HDWalletProvider = require("@truffle/hdwallet-provider")
require('dotenv').config(); // Load .env file

module.exports = {
  networks: {
      development: {
          // from: "", // Defaults to first address from Ganache
          host: "127.0.0.1",
          port: 7545,
          network_id: "*"
      },
      maticmumbai: {
        provider: () => new HDWalletProvider(process.env.MNEMONICMETAMASK, process.env.ALCHEMY_POLYGON_MUMBAI), 
        network_id: 80001,
        confirmations: 2,
        timeoutBlocks: 200,
        skipDryRun: true,
        gas: 6000000,
        gasPrice: 10000000000,
      },
      maticmainnet: {
        provider: function() {
          return new HDWalletProvider(process.env.MNEMONICMETAMASK, process.env.ALCHEMY_POLYGON_MAINNET);
          },
          gas: 600000,
          network_id: '137',
      },
  },
  contracts_directory: './contracts', // path to Smart Contracts
  contracts_build_directory: './build/contracts/', // Path to ABIs
  
  compilers: {
    solc: {
      version: "^0.8.0"
    }
  }
}
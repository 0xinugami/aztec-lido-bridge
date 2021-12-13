import { HardhatUserConfig } from 'hardhat/config';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-spdx-license-identifier';

const config: HardhatUserConfig = {
  spdxLicenseIdentifier: {
    overwrite: true,
    runOnCompile: true
  },
  solidity: {
    version: '0.6.10',
    settings: {
      evmVersion: 'berlin',
      optimizer: { enabled: true, runs: 200 }
    }
  },
  networks: {
    ganache: {
      url: `http://${process.env.GANACHE_HOST || 'localhost'}:8545`
    },
    hardhat: {
      blockGasLimit: 15000000,
      gasPrice: 10,
      hardfork: 'berlin',
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`
      }
    }
  },
  paths: {
    artifacts: './src/artifacts'
  }
};

export default config;

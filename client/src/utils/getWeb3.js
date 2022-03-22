
import detectEthereumProvider from '@metamask/detect-provider'
import { ethers, Contract } from 'ethers';
import EthVault from '../contracts/EthVault.json';

export const available_networks = {
  56 : {
    'address': '0xedf5ECa4e55624D86908aef1dEb46b011912EF1F',
    'token' : 'BNB'
  },

  137: {'address': '0x743D83DDa5984B86f68D2D7aeB2F5961fC82B0Ac', 'token' : 'MATIC'}
}

export async function getWallet() {
  let provider = await detectEthereumProvider()
  if (provider) {
    const networkId = await provider.request({ method: 'net_version' })
    
    provider = new ethers.providers.Web3Provider(provider)
    //get current metamask wallet address
    let addresses = await provider.send('eth_requestAccounts', [])

    console.log('active address ', addresses)

    let currentAddress = addresses[0];

    let currentToken = available_networks[networkId]['token'];

    return [currentAddress, provider, currentToken]
  }
  return 'Install metamask!'
}

export async function getContract() {
  //get the Web3 provider from the frontend (prev window.ethereum)
  let provider = await detectEthereumProvider()
  if (provider) {
    
    
    //get network id to fit the right contract address
    const networkId = await provider.request({ method: 'net_version' })

    //connect wallet to web3 provider
    provider = new ethers.providers.Web3Provider(provider)
    const signer = provider.getSigner()
    //register the smart contract

    let contractAddress = available_networks[networkId]['address'];

    const vaultContract = new Contract(contractAddress, EthVault.abi, signer)
    
    return vaultContract
  }
  return "Problem registering contract";
}

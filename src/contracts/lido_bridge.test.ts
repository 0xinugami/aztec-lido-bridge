import { ethers } from 'hardhat';
import hre from 'hardhat';
import abi from '../artifacts/contracts/LidoBridge.sol/LidoBridge.json';
import { Contract, Signer } from 'ethers';
import { DefiBridgeProxy, AztecAssetType } from './defi_bridge_proxy';
import { formatEther, parseEther } from '@ethersproject/units';
import { WSTETH_ABI } from '../abi/wsteth';

describe('lido defi bridge', function () {
  let bridgeProxy: DefiBridgeProxy;
  let lidoBridgeAddress: string;
  let lidoStakingAddress: string;
  let wstETHAddress: string;
  let wstETH: Contract;
  let signer: Signer;
  let signerAddress: string;

  beforeEach(async () => {
    // reset balance and impersonation each time since amount can change

    await hre.network.provider.request({
      method: 'hardhat_reset',
      params: [
        {
          forking: {
            jsonRpcUrl: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`
          }
        }
      ]
    });

    wstETHAddress = '0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0';
    lidoStakingAddress = '0xae7ab96520de3a18e5e111b5eaab095312d7fe84';
    signerAddress = '0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe';

    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [signerAddress]
    });

    signer = await ethers.getSigner(signerAddress);

    wstETH = new Contract(wstETHAddress, WSTETH_ABI, signer);

    bridgeProxy = await DefiBridgeProxy.deploy(signer);

    lidoBridgeAddress = await bridgeProxy.deployBridge(signer, abi, []);

    await signer.sendTransaction({
      to: bridgeProxy.address,
      value: parseEther('350000')
    });
  });

  it('should stake eth and get stETH back in lido', async () => {
    // Call convert to swap ETH to ERC20 tokens and return them to caller.

    const depositETH = '300000';

    console.log(`Depositing ${depositETH}`);

    const { isAsync, outputValueA, outputValueB } = await bridgeProxy.convert(
      signer,
      lidoBridgeAddress,
      {
        assetType: AztecAssetType.ETH,
        id: 0
      },
      {},
      {
        assetType: AztecAssetType.ERC20,
        id: 1,
        erc20Address: wstETHAddress
      },
      {},
      BigInt(parseEther('300000').toString()),
      1n,
      0n
    );

    console.log(`Output wstETH ${formatEther(outputValueA)}`);

    // check steth balance of bridge proxy
    const proxyBalance = BigInt((await wstETH.balanceOf(bridgeProxy.address)).toString());
    expect(proxyBalance).toBe(outputValueA);

    // ensure output value b is 0
    expect(outputValueB).toBe(0n);

    // ensure async is false
    expect(isAsync).toBe(false);
  });

  it('should stake eth and get stETH back in curve', async () => {
    // Call convert to swap ETH to ERC20 tokens and return them to caller.

    const depositETH = '100';

    console.log(`Depositing ${depositETH}`);

    const { isAsync, outputValueA, outputValueB } = await bridgeProxy.convert(
      signer,
      lidoBridgeAddress,
      {
        assetType: AztecAssetType.ETH,
        id: 0
      },
      {},
      {
        assetType: AztecAssetType.ERC20,
        id: 1,
        erc20Address: wstETHAddress
      },
      {},
      BigInt(parseEther(depositETH).toString()),
      1n,
      0n
    );

    console.log(`Output wstETH ${formatEther(outputValueA)}`);

    // check steth balance of bridge proxy
    const proxyBalance = BigInt((await wstETH.balanceOf(bridgeProxy.address)).toString());
    expect(proxyBalance).toBe(outputValueA);

    // ensure output value b is 0
    expect(outputValueB).toBe(0n);

    // ensure async is false
    expect(isAsync).toBe(false);
  });
});

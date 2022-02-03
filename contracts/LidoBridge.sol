// SPDX-License-Identifier: GPLv2

pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

import {SafeMath} from '@openzeppelin/contracts/math/SafeMath.sol';
import {Math} from '@openzeppelin/contracts/math/Math.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import {IDefiBridge} from './interfaces/IDefiBridge.sol';
import {Types} from './Types.sol';

interface ICurvePool {
    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable returns (uint256);
}

interface ILido {
    function submit(address _referral) external payable returns (uint256);
}

interface IWstETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);

    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}

contract LidoBridge is IDefiBridge {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable rollupProcessor;

    ILido lido = ILido(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IWstETH wrappedStETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    uint8 curveETHIndex = 0;
    uint8 curveStETHIndex = 1;
    ICurvePool curvePool = ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);

    constructor(address _rollupProcessor) public {
        rollupProcessor = _rollupProcessor;
    }

    receive() external payable {}

    function convert(
        Types.AztecAsset calldata inputAssetA,
        Types.AztecAsset calldata,
        Types.AztecAsset calldata outputAssetA,
        Types.AztecAsset calldata,
        uint256 inputValue,
        uint256,
        uint64
    )
        external
        payable
        override
        returns (
            uint256 outputValueA,
            uint256,
            bool isAsync
        )
    {
        require(msg.sender == rollupProcessor, 'LidoBridge: Invalid Caller');

        bool isETHInput = inputAssetA.assetType == Types.AztecAssetType.ETH;
        bool isWstETHInput = inputAssetA.assetType == Types.AztecAssetType.ERC20 && inputAssetA.erc20Address == address(wrappedStETH);

        require(isETHInput || isWstETHInput, 'LidoBridge: Invalid Input');

        isAsync = false;
        outputValueA = isETHInput ? wrapETH(inputValue, outputAssetA) : unwrapETH(inputValue, outputAssetA);
    }

    /**
        Convert ETH -> wstETH
     */
    function wrapETH(uint256 inputValue, Types.AztecAsset calldata outputAsset) private returns (uint256 outputValue) {
        require(
            outputAsset.assetType == Types.AztecAssetType.ERC20 && outputAsset.erc20Address == address(wrappedStETH),
            'LidoBridge: Invalid Output Token'
        );

        // the minimum should be 1ETH:1STETH
        uint256 minOutput = inputValue;

        // Check with curve to see if we can get better exchange rate than 1 ETH : 1 STETH
        // Yes: use curve
        // No: deposit to Lido correct

        uint256 curveStETHBalance = curvePool.get_dy(curveETHIndex, curveStETHIndex, inputValue);

        if (curveStETHBalance > minOutput) {
            // exchange via curve since we can get a better rate
            curvePool.exchange{value: inputValue}(curveETHIndex, curveStETHIndex, inputValue, minOutput);
        } else {
            // deposit directly through lido since we cannot get better rate
            lido.submit{value: inputValue}(rollupProcessor);
        }

        // since stETH is a rebase token, lets wrap it to wstETH before sending it back to the rollupProcessor
        uint256 outputStETHBalance = IERC20(address(lido)).balanceOf(address(this));

        IERC20(address(lido)).safeIncreaseAllowance(address(wrappedStETH), outputStETHBalance);
        outputValue = wrappedStETH.wrap(outputStETHBalance);

        // send wstETH back to the rollup
        IERC20(address(wrappedStETH)).safeTransfer(rollupProcessor, outputValue);
    }

    /**
        Convert wstETH to ETH
     */
    function unwrapETH(uint256 inputValue, Types.AztecAsset calldata outputAsset) private returns (uint256 outputValue) {
        require(outputAsset.assetType == Types.AztecAssetType.ETH, 'LidoBridge: Invalid Output Token');

        // Convert wstETH to stETH so we can exchange it on curve
        uint256 stETH = wrappedStETH.unwrap(inputValue);

        // Exchange stETH to ETH via curve
        IERC20(address(lido)).safeIncreaseAllowance(address(curvePool), stETH);
        outputValue = curvePool.exchange(curveStETHIndex, curveETHIndex, stETH, 0);

        // Send ETH to rollup processor
        payable(rollupProcessor).transfer(outputValue);
    }

    function canFinalise(uint256) external view override returns (bool) {
        return false;
    }

    function finalise(
        Types.AztecAsset calldata,
        Types.AztecAsset calldata,
        Types.AztecAsset calldata,
        Types.AztecAsset calldata,
        uint256,
        uint64
    ) external payable override returns (uint256, uint256) {
        require(false);
    }
}

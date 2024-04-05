// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract ShakescoSwap {
    ISwapRouter public immutable swapRouter;

    address private s_wethAddress;
    address private s_linkAddress;
    address private s_chainLinkAddress;

    uint24 public constant poolFee = 3000;

    constructor(
        ISwapRouter _swapRouter,
        address wethAddress,
        address linkAddress
    ) {
        swapRouter = _swapRouter;
        s_wethAddress = wethAddress;
        s_chainLinkAddress = linkAddress;
    }

    function swapExactInputSingle(
        uint256 amountIn,
        uint256 minAmount
    ) external returns (uint256 amountOut) {
        IERC20 linkToken = IERC20(s_wethAddress);
        linkToken.approve(address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: s_wethAddress,
                tokenOut: s_chainLinkAddress,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: minAmount,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }
}

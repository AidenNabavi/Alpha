Due to the low version of the codebase, it could not be compiled with Foundry, so I updated the version to `0.8.0`. Three changes were made in the codebase:

👉 These changes **do not affect the logic or functionality** of the code; they were made **only to allow compilation**.

---

**1️⃣ ReentrancyGuard and Ownable constructors**

In `ReentrancyGuard` contract:

```solidity
internal` removed from the constructor

constructor() {
    // The counter starts at one to prevent changing it from zero to a non-zero
    // value, which is a more expensive operation.
    _guardCounter = 1;
}
```

In `Ownable` contract too

```solidity
constructor() {
    _owner = msg.sender;
    emit OwnershipTransferred(address(0), _owner);
}
```

---

**2️⃣ Syntax update for timestamps**

All instances now use `block.timestamp`.

---

**3️⃣ Update for external call with ETH**

Original:

```solidity
Goblin(goblin).work.value(sendETH)(id, msg.sender, debt, data);
```

Updated:

```solidity
Goblin(goblin).work{value: sendETH}(id, msg.sender, debt, data);
```

---


j

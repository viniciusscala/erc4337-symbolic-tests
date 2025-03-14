# ERC-4337 EntryPoint Symbolic Tests

This folder contains a Halmos-based symbolic test suite for an ERC-4337-style [EntryPoint](../lib/account-abstraction/contracts/core/EntryPoint.sol) contract. The tests aim to confirm that the EntryPoint correctly handles various edge cases:

1. **Time constraints**  
2. **Gas consumption & limits**  
3. **Deposit & prefund**  
4. **Sender creation**  
5. **Signature & aggregator validation**  
6. **External call failures**  
7. **Delegate call behavior**

All tests use [Halmos cheatcodes](https://github.com/a16z/halmos-cheatcodes) to create symbolic values (e.g., addresses, uint256s, and byte arrays). This allows us to explore the entire state space of possible inputs without having to predefine random or specific values.

## File Overview

- `EntryPointSymbolicTest.sol`: Main test contract containing multiple “check_” test functions, each addressing a specific scenario in the EntryPoint logic.
- `RevertingPaymaster.sol` and `FailingTarget.sol`: Support contracts used in the tests to induce failures or reverts under certain circumstances.

## Test Details

Below is a breakdown of each test function in `EntryPointSymbolicTest.sol`, including the steps it takes and the expected outcome:

---

### 1. `check_timeConstraints()`
**Purpose**: Ensures the EntryPoint reverts for a time-invalid UserOperation (e.g., expired or not yet valid).

**Flow**:
1. Creates symbolic `sender` and `nonce`.
2. Builds a minimal `PackedUserOperation` (`userOp`) with no initCode/callData.
3. Calls `handleOps` with that userOp.
4. Expects revert (`assert(!success)`).

**Why**: The code typically checks if the operation is within a valid time range. This test confirms that out-of-range ops indeed revert.

---

### 2. `check_gasLimits()`
**Purpose**: Symbolically varies verificationGasLimit/callGasLimit. We expect a revert in this example.

**Flow**:
1. Declares symbolic `verificationGasLimit`, `callGasLimit` (bounded under 300k).
2. Packs them into `accountGasLimits`.
3. Calls `handleOps`.
4. Expects revert (`assert(!success)`).

**Why**: Demonstrates how insufficient or mismatched gas limits might be handled (by reverting). If your real code sometimes succeeds, adapt the test accordingly.

---

### 3. `check_depositPrefund_insufficient()`
**Purpose**: Validates that a sender with no deposit fails to pay the pre-fund.

**Flow**:
1. Creates a `sender` with no deposit added to the EntryPoint.
2. Builds a userOp that definitely requires prefunding.
3. Calls `handleOps` and asserts revert (`assert(!success)`).

**Why**: The contract should revert with `"AA21 didn't pay prefund"` if the sender doesn’t have enough deposit.

---

### 4. `check_senderCreation_initCodeTooShort()`
**Purpose**: Confirms that providing an under-20-byte `initCode` triggers a revert like `"AA99 initCode too small"`.

**Flow**:
1. Creates a 10-byte `initCode`.
2. Places it into the userOp’s `initCode`.
3. Calls `handleOps` and expects revert (`assert(!success)`).

**Why**: With ERC-4337, the first 20 bytes of `initCode` must encode a factory address. A shorter `initCode` is invalid.

---

### 5. `check_signatureAggregatorMismatch()`
**Purpose**: Ensures an aggregator mismatch triggers `"AA24 signature error"`.

**Flow**:
1. Builds a userOp with no aggregator in the userOp data.
2. Calls `handleAggregatedOps` specifying a different aggregator address.
3. Asserts it must revert (`assert(!success)`).

**Why**: If the aggregator used in the handle call doesn’t match the account’s aggregator, the signature is invalid.

---

### 6. `check_externalCallFailure_paymaster()`
**Purpose**: Confirms that if the paymaster reverts during `validatePaymasterUserOp`, the overall userOp fails.

**Flow**:
1. Deploys `RevertingPaymaster`.
2. Builds a userOp referencing that paymaster in `paymasterAndData`.
3. Calls `handleOps` and asserts revert (`assert(!success)`).

**Why**: A failing paymaster should cause the entire userOp to revert.

---

### 7. `check_delegateAndRevert_fail()`
**Purpose**: Tests the `delegateAndRevert` function by delegating to a failing contract.

**Flow**:
1. Deploys `FailingTarget`.
2. Invokes `delegateAndRevert` with a call that triggers `FailingTarget.doFail()`.
3. Expects revert (`assert(!success)`).

**Why**: Demonstrates that a failed delegatecall from the entry point does indeed revert.

---

## Support Contracts

- **`RevertingPaymaster`**: Always reverts in `validatePaymasterUserOp`, used to test paymaster reverts.  
- **`FailingTarget`**: Always reverts in `doFail()`, used to verify that `delegateAndRevert` properly reverts.

---

## Running the Tests

1. **Install Halmos** and other dependencies (e.g. via `forge install a16z/halmos-cheatcodes`).
2. In this directory, run:
   ```sh
   halmos
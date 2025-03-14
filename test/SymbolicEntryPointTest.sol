// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Test} from "forge-std/Test.sol";

import {EntryPoint, IEntryPoint, PackedUserOperation} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {IAggregator} from "../lib/account-abstraction/contracts/interfaces/IAggregator.sol";

contract EntryPointSymbolicTest is SymTest, Test {
    EntryPoint ep;

    function setUp() public {
        ep = new EntryPoint();
    }

    function _packUints(
        uint256 high128,
        uint256 low128
    ) internal pure returns (bytes32) {
        return bytes32((high128 << 128) | low128);
    }

    // ----------------------------------------------------------------------
    // 1) Time Constraints Test => "AA22 expired or not due"
    // ----------------------------------------------------------------------
    function check_timeConstraints() public {
        // (1) Declare symbolic inputs
        PackedUserOperation memory userOp;
        userOp.sender = svm.createAddress("sender");
        userOp.nonce = svm.createUint256("nonce");

        // (2)

        userOp.initCode = new bytes(0);
        userOp.callData = new bytes(0);
        userOp.accountGasLimits = bytes32(0);
        userOp.preVerificationGas = 21000;
        userOp.gasFees = _packUints(1e9, 3e9);
        userOp.paymasterAndData = new bytes(0);
        userOp.signature = new bytes(0);

        // (3) Call target
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        (bool success, ) = address(ep).call(
            abi.encodeWithSelector(
                ep.handleOps.selector,
                ops,
                payable(address(1))
            )
        );

        // (4) Expect revert
        assert(!success);
    }

    // ----------------------------------------------------------------------
    // 2) Gas Consumption & Limits
    // ----------------------------------------------------------------------
    function check_gasLimits() public {
        // (1) Declare symbolic inputs
        uint256 verificationGasLimit = svm.createUint256("verificationGas");
        uint256 callGasLimit = svm.createUint256("callGasLimit");

        // (2) Basic assumptions
        vm.assume(verificationGasLimit < 300000);
        vm.assume(callGasLimit < 300000);

        PackedUserOperation memory userOp;
        userOp.sender = svm.createAddress("senderGasTest");
        userOp.nonce = 0;
        userOp.accountGasLimits = bytes32(
            ((verificationGasLimit << 128) | callGasLimit)
        );
        userOp.preVerificationGas = 21000;
        userOp.gasFees = _packUints(1e9, 5e9);
        userOp.initCode = new bytes(0);
        userOp.callData = new bytes(0);
        userOp.paymasterAndData = new bytes(0);
        userOp.signature = new bytes(0);

        // (3) Call
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        (bool success, ) = address(ep).call(
            abi.encodeWithSelector(
                ep.handleOps.selector,
                ops,
                payable(address(0xdead))
            )
        );

        // (4) Revert expected
        assert(!success);
    }

    // ----------------------------------------------------------------------
    // 3) Deposit & Prefund => "AA21 didn't pay prefund"
    // ----------------------------------------------------------------------
    function check_depositPrefund_insufficient() public {
        // (1) Symbolic inputs
        address sender = svm.createAddress("senderNoDeposit");
        uint256 userBalance = svm.createUint256("balance");
        vm.assume(userBalance < 1e10);

        PackedUserOperation memory userOp;
        userOp.sender = sender;
        userOp.nonce = 0;
        userOp.initCode = new bytes(0);
        userOp.callData = new bytes(0);
        userOp.accountGasLimits = _packUints(50000, 50000);
        userOp.preVerificationGas = 21000;
        userOp.gasFees = _packUints(2e9, 2e9);
        userOp.paymasterAndData = new bytes(0);
        userOp.signature = new bytes(0);

        // (2) We'll deposit nothing, so it should fail.

        // (3) Call
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        (bool success, ) = address(ep).call(
            abi.encodeWithSelector(
                ep.handleOps.selector,
                ops,
                payable(address(1234))
            )
        );

        // (4) Revert expected
        assert(!success);
    }

    // ----------------------------------------------------------------------
    // 4) Sender Creation => "AA99 initCode too small"
    // ----------------------------------------------------------------------
    function check_senderCreation_initCodeTooShort() public {
        // (1) 10-byte initCode
        bytes memory tinyInitCode = svm.createBytes(10, "tinyInitCode");
        address senderSym = svm.createAddress("sender4");

        PackedUserOperation memory userOp;
        userOp.sender = senderSym;
        userOp.nonce = 1;
        userOp.initCode = tinyInitCode;
        userOp.callData = new bytes(0);
        userOp.accountGasLimits = bytes32(0);
        userOp.preVerificationGas = 21000;
        userOp.gasFees = _packUints(1e9, 1e9);
        userOp.paymasterAndData = new bytes(0);
        userOp.signature = new bytes(0);

        // (2)-(3) Call
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        (bool success, ) = address(ep).call(
            abi.encodeWithSelector(
                ep.handleOps.selector,
                ops,
                payable(address(9999))
            )
        );

        // (4) Expect revert
        assert(!success);
    }

    // ----------------------------------------------------------------------
    // 5) Signature & Aggregator => "AA24 signature error"
    // ----------------------------------------------------------------------
    function check_signatureAggregatorMismatch() public {
        // (1) Build userOp
        PackedUserOperation memory userOp;
        userOp.sender = svm.createAddress("senderAggregator");
        userOp.nonce = 0;
        userOp.initCode = new bytes(0);
        userOp.callData = new bytes(0);
        userOp.accountGasLimits = bytes32(0);
        userOp.preVerificationGas = 21000;
        userOp.gasFees = _packUints(1e9, 2e9);
        userOp.paymasterAndData = new bytes(0);
        userOp.signature = new bytes(0);

        // (2)-(3) aggregator mismatch
        IEntryPoint.UserOpsPerAggregator[]
            memory opsPerAggregator = new IEntryPoint.UserOpsPerAggregator[](1);
        opsPerAggregator[0].userOps = new PackedUserOperation[](1);
        opsPerAggregator[0].userOps[0] = userOp;
        opsPerAggregator[0].aggregator = IAggregator(address(0x1234)); // mismatch
        opsPerAggregator[0].signature = new bytes(0);

        (bool success, ) = address(ep).call(
            abi.encodeWithSelector(
                ep.handleAggregatedOps.selector,
                opsPerAggregator,
                payable(address(777))
            )
        );

        // (4) Expect revert
        assert(!success);
    }

    // ----------------------------------------------------------------------
    // 6) External Call Failure => "AA33 reverted" or "FailedOpWithRevert"
    // ----------------------------------------------------------------------
    function check_externalCallFailure_paymaster() public {
        // (1) Reverting paymaster
        RevertingPaymaster rpm = new RevertingPaymaster();
        address paymasterAddr = address(rpm);

        PackedUserOperation memory userOp;
        userOp.sender = svm.createAddress("senderExternalFail");
        userOp.nonce = 0;
        userOp.accountGasLimits = bytes32(0);
        userOp.preVerificationGas = 21000;
        userOp.gasFees = _packUints(1e9, 1e9);

        // The first 20 bytes is the paymaster
        bytes memory pmData = abi.encodePacked(
            paymasterAddr,
            uint96(0),
            uint96(0)
        );
        userOp.paymasterAndData = pmData;
        userOp.initCode = new bytes(0);
        userOp.callData = new bytes(0);
        userOp.signature = new bytes(0);

        // (2)-(3) handleOps
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        (bool success, ) = address(ep).call(
            abi.encodeWithSelector(
                ep.handleOps.selector,
                ops,
                payable(address(999999))
            )
        );

        // (4) Expect revert
        assert(!success);
    }

    // ----------------------------------------------------------------------
    // 7) DelegateCall Behavior => call failing target
    // ----------------------------------------------------------------------
    function check_delegateAndRevert_fail() public {
        // (1) Failing target
        FailingTarget failing = new FailingTarget();

        // (2)-(3) delegateAndRevert
        (bool success, ) = address(ep).call(
            abi.encodeWithSelector(
                ep.delegateAndRevert.selector,
                address(failing),
                abi.encodeWithSignature("doFail()")
            )
        );

        // (4) expect revert
        assert(!success);
    }
}

// ----------------------------------------------------------------------
// Support contracts: Reverting paymaster + failing target
// ----------------------------------------------------------------------
contract RevertingPaymaster {
    function validatePaymasterUserOp(
        PackedUserOperation calldata,
        bytes32,
        uint256
    ) external pure returns (bytes memory, uint256) {
        revert("I always revert in validatePaymasterUserOp");
    }
}

contract FailingTarget {
    function doFail() external pure {
        revert("FailingTarget says no");
    }
}

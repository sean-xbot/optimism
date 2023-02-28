// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Test } from "forge-std/Test.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { Vm } from "forge-std/Vm.sol";
import { SafeCall } from "../../libraries/SafeCall.sol";

contract SafeCall_Succeeds_Invariants is Test {
    SafeCaller_Succeeds_Actor actor;

    function setUp() public {
        // Create a new safe caller actor.
        actor = new SafeCaller_Succeeds_Actor(vm);

        // Set the caller to this contract
        targetSender(address(this));

        // Target the safe caller actor.
        targetContract(address(actor));
    }

    /**
     * @custom:invariant `callWithMinGas` forwards at least `minGas` if the call succeeds.
     *
     * If the call to `SafeCall.callWithMinGas` succeeds, then the
     * call must have received at *least* `minGas` gas. If there is not enough gas in
     * the callframe to supply the minimum amount of gas to the call, it must revert.
     */
    function invariant_callWithMinGas_alwaysForwardsMinGas_succeeds() public {
        assertEq(actor.numFailed(), 0, "no failed calls allowed");
    }

    function performSafeCallMinGas(uint64 minGas) external {
        SafeCall.callWithMinGas(address(0), minGas, 0, hex"");
    }
}

contract SafeCall_Fails_Invariants is Test {
    SafeCaller_Fails_Actor actor;

    function setUp() public {
        // Create a new safe caller actor.
        actor = new SafeCaller_Fails_Actor(vm);

        // Set the caller to this contract
        targetSender(address(this));

        // Target the safe caller actor.
        targetContract(address(actor));
    }

    /**
     * @custom:invariant `callWithMinGas` reverts if there is not enough gas to pass
     * to the call.
     *
     * If there is not enough gas in the callframe to ensure that
     * `SafeCall.callWithMinGas` will receive at least `minGas` gas, then the call
     * must revert.
     */
    function invariant_callWithMinGas_neverForwardsMinGas_reverts() public {
        assertEq(actor.numSuccessful(), 0, "no successful calls allowed");
    }

    function performSafeCallMinGas(uint64 minGas) external {
        SafeCall.callWithMinGas(address(0), minGas, 0, hex"");
    }
}

contract SafeCaller_Succeeds_Actor is StdUtils {
    Vm internal vm;
    uint256 public numFailed;

    constructor(Vm _vm) {
        vm = _vm;
    }

    function performSafeCallMinGas(uint64 gas, uint64 minGas) external {
        // Bound the minimum gas amount to [2500, type(uint48).max]
        minGas = uint64(bound(minGas, 2500, type(uint48).max));
        // Bound the gas passed to [(((minGas + 200) * 64) / 63) + 500, type(uint64).max]
        gas = uint64(bound(gas, (((minGas + 200) * 64) / 63) + 500, type(uint64).max));

        vm.expectCallMinGas(address(0x00), 0, minGas, hex"");
        bool success = SafeCall.call(
            msg.sender,
            gas,
            0,
            abi.encodeWithSelector(
                SafeCall_Succeeds_Invariants.performSafeCallMinGas.selector,
                minGas
            )
        );

        if (!success) numFailed++;
    }
}

contract SafeCaller_Fails_Actor is StdUtils {
    Vm internal vm;
    uint256 public numSuccessful;

    constructor(Vm _vm) {
        vm = _vm;
    }

    function performSafeCallMinGas(uint64 gas, uint64 minGas) external {
        // Bound the minimum gas amount to [2500, type(uint48).max]
        minGas = uint64(bound(minGas, 2500, type(uint48).max));
        // Bound the gas passed to [minGas, (((minGas + 200) * 64) / 63)]
        gas = uint64(bound(gas, minGas, (((minGas + 200) * 64) / 63)));

        vm.expectCallMinGas(address(0x00), 0, minGas, hex"");
        bool success = SafeCall.call(
            msg.sender,
            gas,
            0,
            abi.encodeWithSelector(SafeCall_Fails_Invariants.performSafeCallMinGas.selector, minGas)
        );

        if (success) numSuccessful++;
    }
}

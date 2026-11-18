// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Composability probe for domain access control: reads a token balance from
/// inside another contract so the execution client evaluates `canCall(reader, token, ...)`
/// for the nested CALL. `tryRead` swallows the inner failure to show that a denied frame
/// still reverts the whole transaction on the client.
contract BalanceReader {
    uint256 public lastBalance;
    uint256 public reads;

    function read(address token, address subject) external returns (uint256 balance) {
        balance = IERC20(token).balanceOf(subject);
        lastBalance = balance;
        reads += 1;
    }

    function tryRead(address token, address subject) external returns (bool ok, uint256 balance) {
        try IERC20(token).balanceOf(subject) returns (uint256 value) {
            ok = true;
            balance = value;
        } catch {
            ok = false;
        }
        lastBalance = balance;
        reads += 1;
    }
}

/// @notice Simulation probe for `eth_createAccessList` `state_overrides` tests: reads
/// `token.balanceOf(subject)` and touches storage slot `bytes32(balance)` on its own
/// stateless account (touching no other slot so MIP-8 page deduplication retains the exact key),
/// causing an unguarded `AccessListTracer` to echo the 256-bit balance in `storageKeys`.
contract AccessListBalanceProbe {
    function probe(address token, address subject) external view {
        uint256 bal = IERC20(token).balanceOf(subject);
        assembly ("memory-safe") {
            pop(sload(bal))
        }
    }
}

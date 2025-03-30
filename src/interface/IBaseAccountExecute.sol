// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/interface/PackedUserOperation.sol";

interface IBaseAccountExecute {
    function execute(
        address to,
        uint256 value,
        bytes memory functionData
    ) external;
}
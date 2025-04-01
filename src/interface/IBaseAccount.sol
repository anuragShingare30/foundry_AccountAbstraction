// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/interface/PackedUserOperation.sol";

interface IBaseAccount {

    function validateUserOps(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns(uint256 validationData);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/interface/PackedUserOperation.sol";

interface IBaseAccount {

    function validateUserOps(
        PackedUserOperation memory userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns(uint256 validationData);
}
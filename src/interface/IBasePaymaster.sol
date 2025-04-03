// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/interface/PackedUserOperation.sol";

interface IBasePaymaster {

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns(uint256 validationData);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/interface/PackedUserOperation.sol";

interface IEntryPoint {
    function handleOps(
        PackedUserOperation[] calldata ops,
        address payable beneficiary
    ) external;

    function handleOperation(
        PackedUserOperation calldata ops,
        address payable beneficiaryAddress
    ) external returns(uint256);

    function getUserOpHash(
        PackedUserOperation calldata userOp
    ) external view returns (bytes32);
}
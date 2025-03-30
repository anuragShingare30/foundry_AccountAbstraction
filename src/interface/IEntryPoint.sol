pragma solidity ^0.8.26;

import "src/interface/PackedUserOperation.sol";

interface IEntryPoint {
    function handleOps(
        PackedUserOperation[] calldata ops,
        address payable beneficiary
    ) external;

    function getUserOpHash(
        PackedUserOperation calldata userOp
    ) external view returns (bytes32);
}
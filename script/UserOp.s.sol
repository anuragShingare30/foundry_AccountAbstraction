// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/interface/PackedUserOperation.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import "lib/forge-std/src/console.sol"; 
import "lib/forge-std/src/Vm.sol";
import {BaseAccount} from "src/BaseAccount.sol";
import {EntryPoint} from "src/EntryPoint.sol";
import {IEntryPoint} from "src/interface/IEntryPoint.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";


contract UserOp is Script {
    using MessageHashUtils for bytes32;

    HelperConfig public helperConfig;
    uint256 constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function setUp() public {
        BaseAccount baseAccount;
        HelperConfig config;
    }

    /**
     @notice generateSignedUserOp function
     * This function will generate the userOps
     * If paymaster is present pass the paymaster address
     * Else keep the field  as address(0)
     */
    function generateSignedUserOp(
        bytes memory executionData,
        HelperConfig.NetworkConfig memory config,
        address baseAccount,
        address paymaster
    ) public returns(PackedUserOperation memory){

        bytes memory paymasterAndData = abi.encodePacked(
            paymaster,
            keccak256(abi.encode(10))
        );

        uint256 nonce = vm.getNonce(baseAccount)-1;
        PackedUserOperation memory userOp = _generateUnSignedUserOp(baseAccount, nonce, executionData,paymasterAndData);

        // get the userOpHash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // generate the signature
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v,r,s) = vm.sign(ANVIL_PRIVATE_KEY,digest);

        // AA user will sign the userOp -> Later after for verification we will use this signature
        userOp.signature = abi.encodePacked(r,s,v);

        // return the userOp signed by baseAccount owner
        return userOp;
    }

    function _generateUnSignedUserOp(
        address sender,
        uint256 nonce,
        bytes memory functionData,
        bytes memory paymasterAndData
    ) internal returns(PackedUserOperation memory){
        
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            // sender:sender,
            // nonce:nonce,
            // initCode:hex"",
            // callData:functionData,
            // paymasterAndData: hex"",
            // signature: hex""
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: functionData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: paymasterAndData,
            signature: hex""
            // paymaster:address(0)
        });
    }
}
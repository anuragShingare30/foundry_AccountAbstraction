// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/interface/PackedUserOperation.sol";
import "src/interface/IBaseAccount.sol";
import "src/interface/IBaseAccountExecute.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard } from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract EntryPoint is ReentrancyGuard {
    /////////////////////
    // Error //
    /////////////////////
    error EntryPoint_validateUserOpFailed(bytes returnData, address sender);
    error EntryPoint_validationOfUserFailedForValidationData(uint256 validationData);
    error EntryPoint_ValidationFailedDuringExecution(bytes returnData);

    /////////////////////
    // Type Declaration //
    /////////////////////
    struct UserOpInfo{
        address sender; // baseAccount address
        uint256 nonce;
        address paymaster; // for now not considered
        bytes32 userOpHash; // main
        uint256 gasFees;
    }


    /////////////////////
    // Events //
    /////////////////////
    event EntryPoint_ExecutionFailed(address sender);


    /////////////////////
    // External Functions //
    /////////////////////

    /**
     * Execute a batch of UserOperations.
     * No signature aggregator is used.
     * If any account requires an aggregator (that is, it returned an aggregator when
     * performing simulateValidation), then handleAggregatedOps() must be used instead.
     * @param ops         - The operations to execute.
     * @param beneficiaryAddress - The address to receive the fees.

     @notice We will follow the below Flow for handleOps function:
        a. validate all the userOp one-by-one -> those who fails validation discard them from array
        b. after validation of all valid userOps -> execute the function for each userOp
        c. Track the gas usage across all execution operation -> refund ETH to the executor/beneficiary address
     */
    function handleOps(
        PackedUserOperation[] calldata ops,
        address payable beneficiaryAddress
    ) external nonReentrant{
        uint256 opsLength = ops.length;
        UserOpInfo[] memory opsInfo = new UserOpInfo[](opsLength);

        uint256 validCnt = _iterateToValidateUserOp(ops,opsInfo,0);

        for(uint256 i=0;i<validCnt;i++){
            // to execute function that are valid
            _iterateToExecuteUserOp(i,ops[i],opsInfo[i]);
        }

        // uint256 amountToBeSent = 0;
        // _payToExecutor(beneficiaryAddress,amountToBeSent);
    }


    /////////////////////
    // Internal Functions //
    /////////////////////
    

    /**
     * validate all the userOp one-by-one -> those who fails validation discard them from array
     */
    function _iterateToValidateUserOp(
        PackedUserOperation[] calldata ops,
        UserOpInfo[] memory opsInfo,
        uint256 opIndex
    ) internal returns(uint256 validCount) {
        uint256 opsLen = ops.length;
        uint256 validCount = 0;
        for(uint256 i=0;i<opsLen;i++){
            UserOpInfo memory opInfo = opsInfo[opIndex+i];
            (uint256 validationData) = _validateUserOp(ops[i],opInfo,opIndex+i);
            // _checkValidationDataForUserOp(
            //     opIndex+i,
            //     validationData
            // );
            if (validationData == 1) {
                continue; // Skip invalid UserOp
            }
            opsInfo[validCount] = opInfo;
            validCount++;
        }

        return validCount;
    }

    function _validateUserOp(
        PackedUserOperation memory userOp,
        UserOpInfo memory opInfo,
        uint256 opIndex
    ) internal returns(uint256 validationData){
        opInfo.sender = userOp.sender; // baseAccount owner
        opInfo.nonce = userOp.nonce; // create a nonce getter/manager
        opInfo.paymaster = address(2); 
        opInfo.gasFees = 0;
        opInfo.userOpHash = getUserOpHash(userOp);
        uint256 missingAccountFunds = 0;
        
        // call the validateUserOp() from sender using low-level calls
        // get the function selector
        bytes memory callData = abi.encodeWithSelector(
            IBaseAccount.validateUserOps.selector,
            userOp,
            opInfo.userOpHash,
            missingAccountFunds
        );

        // call the function using low-level call
        address sender = userOp.sender;
        (bool success,bytes memory returnData) = payable(sender).call{value:0}(callData);

        // check if the call succeded or not
        // we will check for two params (success and retunData)
        if(!success || returnData.length != 32){
            revert EntryPoint_validateUserOpFailed(returnData,sender);
        } 

        // Decode validationData from returnData
        validationData = abi.decode(returnData,(uint256));
    }

    function _checkValidationDataForUserOp(
        uint256 opIndex,
        uint256 validationData
    ) internal {
        if(validationData == 1){
            revert EntryPoint_validationOfUserFailedForValidationData(validationData);
        }
    }

    /**
     * after validation of all valid userOps -> execute the function for each userOp
     */
    function _iterateToExecuteUserOp(
    uint256 opIndex,
    PackedUserOperation memory userOp,
    UserOpInfo memory opInfo
) internal {
    // Extract function data from UserOp
    bytes memory functionData = userOp.callData;

    // Encode function call for execute()
    bytes memory executionData = abi.encodeWithSelector(
        IBaseAccountExecute.execute.selector,
        userOp.sender, // The `to` address (destination of execution)
        0,
        functionData
    );

    // Call the execute function on the user's contract
    (bool success, bytes memory returnData) = opInfo.sender.call{value: 0}(executionData);

    // Check if execution was successful
    if (!success) {
        emit EntryPoint_ExecutionFailed(userOp.sender);
        return;
    }
}


    /**
     * Track the gas usage across all execution operation -> refund ETH to the executor/beneficiary address
     */
    function _payToExecutor(
        address beneficiaryAddress,
        uint256 amountToBeSent
    ) internal {}


    /////////////////////
    // Getter Functions //
    /////////////////////

    function getUserOpHash(
        PackedUserOperation memory userOp
    ) public view returns(bytes32){
        return keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                keccak256(userOp.paymasterAndData),
                userOp.paymaster,
                keccak256(userOp.signature),
                address(this)
            )
        );
    }
}
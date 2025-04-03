// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IBaseAccount} from "src/interface/IBaseAccount.sol";
import {IBasePaymaster} from "src/interface/IBasePaymaster.sol";
import {IBaseAccountExecute} from "src/interface/IBaseAccountExecute.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard } from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {EIP712} from "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {Eip7702Support} from "lib/account-abstraction/contracts/core/Eip7702Support.sol";
import {UserOperationLib} from "lib/account-abstraction/contracts/core/UserOperationLib.sol";
import {IEntryPoint} from "src/interface/IEntryPoint.sol";
import {console} from "lib/forge-std/src/console.sol";

contract EntryPoint is ReentrancyGuard,EIP712 {
    using MessageHashUtils for bytes32;
    using UserOperationLib for PackedUserOperation;
    /////////////////////
    // Error //
    /////////////////////
    error EntryPoint_validateUserOpFailed(bytes returnData, address sender);
    error EntryPoint_validationOfUserFailedForValidationData(uint256 validationData);
    error EntryPoint_ValidationFailedDuringExecution(bytes returnData);
    error EntryPoint_executionFailed(bytes returnData);
    error EntryPoint_zeroAmountNotAllowed();
    error EntryPoint_FailedToWithDrawAmount();
    error EntryPoint_InsufficientBalanceToWithDraw();

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

    mapping (address paymaster => uint256 totalDeposit) public immutable i_deposit;


    /////////////////////
    // State Variables //
    /////////////////////
    string constant internal DOMAIN_NAME = "ERC4337";
    string constant internal DOMAIN_VERSION = "1";
    uint256 private constant SIG_VALIDATION_FAILED = 1;
    uint256 private constant SIG_VALIDATION_SUCCESS = 0;

    /////////////////////
    // Events //
    /////////////////////
    event EntryPoint_ExecutionFailed(address sender);


    /////////////////////
    // External Functions //
    /////////////////////
    
    constructor() EIP712(DOMAIN_NAME, DOMAIN_VERSION){}

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

    function handleOperation(
        PackedUserOperation calldata userOp,
        address payable beneficiaryAddress
    ) external nonReentrant() returns(uint256){
        uint256 validationData;
        // validate user
        if(userOp.paymasterAndData.length>0){
            validationData = _checkValidationForPaymasterOp(userOp);
        }
        else{
            validationData = _checkValidityForUserOp(userOp);
        }
        

        // execute the function
        if(validationData == 0 || validationData == 1){
            _executeCallData(userOp);
        }

        // pay the TNX fee to beneficiary

        return validationData;
    }

    function deposit(
        address paymasterAddress
    ) external payable{
        if(msg.value <= 0){
            revert EntryPoint_zeroAmountNotAllowed();
        }
        uint256 depositedAmount = msg.value;
        i_deposit[paymasterAddress] += depositedAmount;
    }

    function withDrawDeposit(
        uint256 withDrawAmount
    ) external payable {
        if(i_deposit[msg.sender] < withDrawAmount){
            revert EntryPoint_InsufficientBalanceToWithDraw();
        }
        i_deposit[msg.sender] -= withDrawAmountl;
        (bool success,) = payable(msg.sender).call{value:withDrawAmount}();
        if(!success){
            revert EntryPoint_FailedToWithDrawAmount();
        }
    }


    /////////////////////
    // Internal Functions //
    /////////////////////
    
    function _checkValidityForUserOp(
        PackedUserOperation calldata userOp
    ) internal returns(uint256 validationData){
        bytes32 userOpHash = getUserOpHash(userOp);
        bytes memory functionData = abi.encodeWithSelector(
            IBaseAccount.validateUserOps.selector,
            userOp,
            userOpHash
        );
        console.log("Current msg.sender",msg.sender);
        (bool success, bytes memory returnData) = payable(msg.sender).staticcall(functionData);
        if(!success){
            if (returnData.length > 0) {
            assembly {
                let returndata_size := mload(returnData)
                revert(add(32, returnData), returndata_size)
            }
        } else {
            revert EntryPoint_validateUserOpFailed(returnData,msg.sender);
            }
        }
        validationData = abi.decode(returnData,(uint256));
    }

    function _checkValidationForPaymasterOp(
        PackedUserOperation calldata userOp
    ) internal returns(uint256 validationData){
        bytes32 userOpHash = getUserOpHash(userOp);
        bytes memory functionData = abi.encodeWithSelector(
            IBasePaymaster.validatePaymasterUserOp.selector,
            userOp,
            userOpHash
        );
        console.log("Current msg.sender",msg.sender);
        (bool success, bytes memory returnData) = payable(msg.sender).staticcall(functionData);
        if(!success){
            if (returnData.length > 0) {
            assembly {
                let returndata_size := mload(returnData)
                revert(add(32, returnData), returndata_size)
            }
        } else {
            revert EntryPoint_validateUserOpFailed(returnData,msg.sender);
            }
        }
        validationData = abi.decode(returnData,(uint256));
    }

    function _executeCallData(
        PackedUserOperation memory userOp
    ) internal {
        bytes memory functionData = userOp.callData;
        address sender = userOp.sender;
        (bool success,bytes memory returnData) = payable(sender).call{value:0}(
            functionData
        );
        if(!success){
            revert EntryPoint_executionFailed(returnData);
        }
    }

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
        PackedUserOperation calldata userOp,
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

    function getDepositOfUser(address user) public view returns(uint256){
        return i_deposit[user];
    }

    function getUserOpHash(
        PackedUserOperation calldata userOp
    ) public view returns(bytes32){

        bytes32 overrideInitCodeHash = Eip7702Support._getEip7702InitCodeHashOverride(userOp);
        return
            MessageHashUtils.toTypedDataHash(getDomainSeparatorV4(), userOp.hash(overrideInitCodeHash));
        
        // return keccak256(
        //     abi.encode(
        //         userOp.sender,
        //         userOp.nonce,
        //         keccak256(userOp.initCode),
        //         keccak256(userOp.callData),
        //         userOp.accountGasLimits,
        //         userOp.preVerificationGas,
        //         userOp.gasFees,
        //         keccak256(userOp.paymasterAndData),
        //         keccak256(userOp.signature),
        //         address(this),
        //         block.chainid
        //     )
        // );
    }

    /////////////////////
    // Helper Functions //
    /////////////////////

    function getDomainSeparatorV4() public virtual view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
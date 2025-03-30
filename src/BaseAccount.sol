// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "src/interface/PackedUserOperation.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {EntryPoint} from "src/EntryPoint.sol";


contract BaseAccount is Ownable {
    using MessageHashUtils for bytes32;

    //////////////////////////
    // Errors //
    //////////////////////////
    error BaseAccount_ValidationFailedDuringExecution(bytes functionData);
    error BaseAccount_NotFromOwnerOfBaseAccount();
    error BaseAccount_NotFromOwnerOrEntryPoint();

    //////////////////////////
    // Type Declaration //
    //////////////////////////
    
    //////////////////////////
    // State Variables //
    //////////////////////////
    EntryPoint public immutable i_entryPoint;
    uint256 private constant SIG_VALIDATION_FAILED = 1;
    uint256 private constant SIG_VALIDATION_SUCCESS = 0;

    //////////////////////////
    // Modifiers //
    //////////////////////////
    modifier NotFromOwnerOfBaseAccount(){
        if(msg.sender != owner()){
            revert BaseAccount_NotFromOwnerOfBaseAccount();
        }
        _;
    }
    modifier NotFromOwnerOrEntryPoint(){
        if(msg.sender != owner() && msg.sender != address(i_entryPoint)){
            revert BaseAccount_NotFromOwnerOrEntryPoint();
        }
        _;
    }


    //////////////////////////
    // External functions //
    //////////////////////////
    constructor(address _entryPoint) Ownable(msg.sender){
        i_entryPoint = EntryPoint(_entryPoint);
    }

    /**
     @notice validateUserOps function
     * This function will take the userOp,userOpHash to validate the userOp is signed by the valid user

     @param userOp userOperation Struct
     @param userOpHash keccak256 hash of userOp
     @param missingAccountFunds funds
     @return validationData After successfull validation returns 0 else 1
     */
    function validateUserOps(
        PackedUserOperation memory userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external NotFromOwnerOfBaseAccount() returns(uint256 validationData){
        validationData = _validateUserOp(userOp,userOpHash,missingAccountFunds);
    }

    /**
     @notice execute function
     * This function will execute the function mention in functionData
     * Here, we will use low-level functions and methods to execute the function

     @param to to address
     @param value value of token need to be send to 'to' address
     @param functionData hash of the function need to be executed
     */
    function execute(
        address to,
        uint256 value,
        bytes memory functionData
    ) external NotFromOwnerOrEntryPoint(){
        (bool success,) = to.call{value:value}(functionData);
        if(!success){
            revert BaseAccount_ValidationFailedDuringExecution(functionData);
        }
    }

    //////////////////////////
    // Getter functions //
    //////////////////////////
    function getEntryPoint() public view returns(address){
        return address(i_entryPoint);
    }

    //////////////////////////
    // Internal functions //
    //////////////////////////
    function _validateUserOp(
        PackedUserOperation memory userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) internal returns(uint256){
        bytes32 userOpHashData = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(userOpHashData, userOp.signature);

        if(signer != owner()){
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

}
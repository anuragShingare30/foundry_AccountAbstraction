// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "src/interface/PackedUserOperation.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {EntryPoint} from "src/EntryPoint.sol";

contract BasePaymaster is Ownable {
    using MessageHashUtils for bytes32;

    error BaseAccount_NotFromOwnerOfBaseAccount();

    EntryPoint private immutable i_entryPoint;

    modifier NotFromOwnerOfBaseAccount(){
        if(msg.sender != owner()){
            revert BaseAccount_NotFromOwnerOfBaseAccount(); 
        }
        _;
    }

    constructor(address _entryPoint) Ownable(msg.sender){
        i_entryPoint = EntryPoint(_entryPoint);
    }

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external NotFromOwnerOfBaseAccount() returns(uint256 validationData) {
        validationData = _validateUserOp(userOp,userOpHash);
    }

    function getEntryPoint() public view returns(address){
        return address(i_entryPoint);
    }

    function _validateUserOp(
        PackedUserOperation memory userOp,
        bytes32 userOpHash
    ) internal returns(uint256){
        // bytes32 userOpHashData = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        // address signer = ECDSA.recover(userOpHashData, userOp.signature);

        // if(signer != owner()){
        //     return SIG_VALIDATION_FAILED;
        // }
        // return SIG_VALIDATION_SUCCESS;
        return 0;
    }
}
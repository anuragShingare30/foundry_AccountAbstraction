// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";
import "lib/forge-std/src/Vm.sol";
import {BaseAccount} from "src/BaseAccount.sol";
import {EntryPoint} from "src/EntryPoint.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import "src/interface/PackedUserOperation.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployBaseAccount} from "script/DeployBaseAccount.s.sol";
import {UserOp} from "script/UserOp.s.sol";
import {IEntryPoint} from "src/interface/IEntryPoint.sol";

contract TestBaseAccount is Test{
    using MessageHashUtils for bytes32;

    HelperConfig public helperConfig;
    BaseAccount public baseAccount;
    ERC20Mock public usdc;
    UserOp public userOp;

    address public user = makeAddr("user");
    uint256 public AMOUNT = 1e18;
    uint256 public ANVIL_CHAINID = 31337;
    uint256 private constant SIG_VERIFICATION_SUCCESS = 0;
    uint256 private constant SIG_VERIFICATION_FAILED = 1;


    function setUp() public {
        DeployBaseAccount deployBaseAccount = new DeployBaseAccount();
        (baseAccount,helperConfig) = deployBaseAccount.run();

        usdc = new ERC20Mock();
        userOp = new UserOp();

        vm.deal(address(baseAccount),AMOUNT);
    }


    function test_checkOwnerCanExecute() public {
        assert(usdc.balanceOf(address(baseAccount)) == 0);

        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(baseAccount), AMOUNT);
        vm.startPrank(baseAccount.owner());
        baseAccount.execute(address(usdc), 0, functionData);
        vm.stopPrank();

        assert(usdc.balanceOf(address(baseAccount)) == AMOUNT);
    }

    function test_RevertsIf_NonOwnerExecuteFunction() public {
        assert(usdc.balanceOf(address(baseAccount)) == 0);

        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(baseAccount), AMOUNT);
        vm.startPrank(user);
        vm.expectRevert(BaseAccount.BaseAccount_NotFromOwnerOrEntryPoint.selector);
        baseAccount.execute(address(usdc), 0, functionData);
        vm.stopPrank();
    }

    function test_getUserOpHashFunction() public {

        HelperConfig.NetworkConfig memory config = helperConfig.getAnvilConfig();

        bytes memory functionData = abi.encodeWithSelector(
            usdc.mint.selector,
            address(baseAccount),
            AMOUNT
        );
        bytes memory executionData = abi.encodeWithSelector(
            baseAccount.execute.selector,
            address(usdc),
            0,
            functionData
            );

        PackedUserOperation memory userOp = userOp.generateSignedUserOp(executionData, config, address(baseAccount),address(0));

        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);

        bytes32 digest = userOpHash.toEthSignedMessageHash();
        address signer = ECDSA.recover(digest, userOp.signature);

        console.log("getUserOpFunction signer address ->", signer);
        console.log("Actual userOp Signer ->", baseAccount.owner());
    }

    function test_validateUserOps() public {
        // Arrange
        assert(usdc.balanceOf(address(baseAccount)) == 0);

        HelperConfig.NetworkConfig memory config = helperConfig.getAnvilConfig();

        bytes memory functionData = abi.encodeWithSelector(
            usdc.mint.selector,
            address(baseAccount),
            AMOUNT
        );
        bytes memory executionData = abi.encodeWithSelector(
            baseAccount.execute.selector,
            address(usdc),
            0,
            functionData
        );

        PackedUserOperation memory userOp = userOp.generateSignedUserOp(executionData, config, address(baseAccount),address(0));

        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp).toEthSignedMessageHash();

        // Act
        vm.startPrank(baseAccount.owner());
        uint256 validationData = baseAccount.validateUserOps(userOp, userOpHash);
        vm.stopPrank();

        // Assert
        assert(validationData == SIG_VERIFICATION_SUCCESS);
    }

    function test_checkUserOp() public {
        HelperConfig.NetworkConfig memory config = helperConfig.getAnvilConfig();

        bytes memory functionData = abi.encodeWithSelector(
            usdc.mint.selector,
            address(baseAccount),
            AMOUNT
        );
        bytes memory executionData = abi.encodeWithSelector(
            baseAccount.execute.selector,
            address(usdc),
            0,
            functionData
        );

        PackedUserOperation memory userOp = userOp.generateSignedUserOp(executionData, config, address(baseAccount),address(0));

        bytes memory callData = userOp.callData;
        console.logBytes(callData);
        console.log(userOp.sender);
        console.log(address(baseAccount));
        console.log(baseAccount.owner());
    }

    function test_checkHandleOps() public {
        // Arrange
        assert(usdc.balanceOf(address(baseAccount)) == 0);

        HelperConfig.NetworkConfig memory config = helperConfig.getAnvilConfig();

        bytes memory functionData = abi.encodeWithSelector(
            usdc.mint.selector,
            address(baseAccount),
            AMOUNT
        );
        bytes memory executionData = abi.encodeWithSelector(
            baseAccount.execute.selector,
            address(usdc),
            0,
            functionData
        );

        PackedUserOperation memory userOp = userOp.generateSignedUserOp(executionData, config, address(baseAccount),address(0));

        // Act
        vm.startPrank(baseAccount.owner());
        (uint256 validationData) = IEntryPoint(config.entryPoint).handleOperation(userOp, payable(user));
        vm.stopPrank();

        // Assert
        // assert(usdc.balanceOf(address(baseAccount)) == AMOUNT);
        console.log("ValidationData :",validationData);
    }

    // Check the paymaster contract
    function test_IncludePaymasterDataInUserOp() public {
        // Arrange
        HelperConfig.NetworkConfig memory config = helperConfig.getAnvilConfig();

        bytes memory functionData = abi.encodeWithSelector(
            usdc.mint.selector,
            address(baseAccount),
            AMOUNT
        );
        bytes memory executionData = abi.encodeWithSelector(
            baseAccount.execute.selector,
            address(usdc),
            0,
            functionData
        );

        // append the paymaster address
        address paymaster = 0xECe6dcc60bBDfE74a67CB26b1B83af791Aa22AE6;
        PackedUserOperation memory userOp = userOp.generateSignedUserOp(executionData, config, address(baseAccount),paymaster);

        bytes memory paymasterAndData = userOp.paymasterAndData;

        // decode the paymasterdata to get the paymaster address
        require(paymasterAndData.length >= 20, "Invalid paymasterAndData");
        address decodedPaymaster;
         assembly {
        decodedPaymaster := mload(add(paymasterAndData, 20))
        }   
        
        console.log("Decoded paymaster address is:", decodedPaymaster);
        assert(decodedPaymaster == paymaster);
    }


    function test_checkHandleOperationForPaymaster() public {
        // Arrange
        HelperConfig.NetworkConfig memory config = helperConfig.getAnvilConfig();

        bytes memory functionData = abi.encodeWithSelector(
            usdc.mint.selector,
            address(baseAccount),
            AMOUNT
        );
        bytes memory executionData = abi.encodeWithSelector(
            baseAccount.execute.selector,
            address(usdc),
            0,
            functionData
        );

        // append the paymaster address
        address paymaster = 0xECe6dcc60bBDfE74a67CB26b1B83af791Aa22AE6;
        PackedUserOperation memory userOp = userOp.generateSignedUserOp(executionData, config, address(baseAccount),paymaster);

        // Act
        vm.startPrank(baseAccount.owner());
        (uint256 validationData) = IEntryPoint(config.entryPoint).handleOperation(userOp, payable(user));
        vm.stopPrank();

        bytes memory paymasterAndData = userOp.paymasterAndData;

        // decode the paymasterdata to get the paymaster address
        require(paymasterAndData.length >= 20, "Invalid paymasterAndData");
        address decodedPaymaster;
        assembly {
        decodedPaymaster := mload(add(paymasterAndData, 20))
        }         

        // Assert
        console.log("Validation Data:", validationData);
        console.log("Decoded paymaster address:",decodedPaymaster);
    }
}
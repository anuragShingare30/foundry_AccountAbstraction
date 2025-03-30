// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test,console} from "lib/forge-std/src/Test.sol";
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
// import "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "src/interface/IEntryPoint.sol";

contract TestBaseAccount is Test{
    using MessageHashUtils for bytes32;

    HelperConfig public helperConfig;
    BaseAccount public baseAccount;
    ERC20Mock public usdc;
    UserOp public userOp;

    address public user = makeAddr("user");
    uint256 public AMOUNT = 1e18;
    uint256 public ANVIL_CHAINID = 31337;


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

    function test_varifyValidSigFromUserOp() public {

        HelperConfig.NetworkConfig memory config = helperConfig.getAnvilConfig();

        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(baseAccount), AMOUNT);
        bytes memory executionData = abi.encodeWithSelector(baseAccount.execute.selector, address(usdc),0,functionData);

        PackedUserOperation memory userOps = userOp.generateSignedUserOp(executionData, config , address(baseAccount));

        // get the actual userOps signer from userOpHash -> ECDSA
        bytes memory signature = userOps.signature;
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOps);

        address userOpsSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(),signature);
        console.log("userOpSigner address:", userOpsSigner);
        console.log("AA user who signed the userOps:", baseAccount.owner());

        assert(userOpsSigner == baseAccount.owner());
    }
}
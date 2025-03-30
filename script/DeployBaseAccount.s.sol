// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "lib/forge-std/src/Script.sol";
import "lib/forge-std/src/console.sol"; 
import "lib/forge-std/src/Vm.sol";
import {BaseAccount} from "src/BaseAccount.sol";
import {EntryPoint} from "src/EntryPoint.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";


contract DeployBaseAccount is Script{
    BaseAccount public baseAccount;

    function run() public returns(BaseAccount,HelperConfig){
        return setUp();
    }

    function setUp() public returns(BaseAccount,HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getAnvilConfig();

        vm.startBroadcast();
        baseAccount = new BaseAccount(config.entryPoint);
        baseAccount.transferOwnership(config.account);
        vm.stopBroadcast();

        return (baseAccount,helperConfig);
    }
}
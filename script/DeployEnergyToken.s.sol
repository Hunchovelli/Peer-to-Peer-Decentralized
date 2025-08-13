// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {EnergyToken} from "../src/EnergyToken.sol";
import {console} from "forge-std/console.sol";

contract DeployEnergyToken is Script {
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18; // 1 million tokens with 18 decimals

    function run() external {
        vm.startBroadcast();
        EnergyToken energyToken = new EnergyToken(INITIAL_SUPPLY);
        vm.stopBroadcast();
        console.log("EnergyToken deployed at:", address(energyToken));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EnergyToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("EnergyToken", "ET") {
        _mint(msg.sender, initialSupply);
    }
}

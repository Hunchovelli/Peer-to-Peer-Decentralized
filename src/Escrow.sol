// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EnergyToken.sol"; // Import the EnergyToken contract

contract Escrow {
    EnergyToken public energyToken; // Reference to the EnergyToken contract
    address public owner;
    uint256 public rate = 100; // 1 Eth  = 100 EnergyTokens

    constructor(address _energyToken) {
        energyToken = EnergyToken(_energyToken); // Initialize the EnergyToken contract
        owner = msg.sender; // Set the contract deployer as the owner
    }

    function buyEnergyTokens() external payable {
        require(msg.value > 0, "You must send Ether to buy Energy Tokens");
        uint256 tokensToBuy = msg.value * rate; // Calculate the number of tokens to buy
        //energyToken.mint(msg.sender, tokensToBuy); // Mint the tokens to the buyer
    }

    function withdraw() external {
        require(msg.sender == owner, "Only the owner can withdraw funds");
        payable(owner).transfer(address(this).balance); // Transfer the contract's balance to the owner
    }
}

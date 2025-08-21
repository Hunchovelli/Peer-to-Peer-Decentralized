// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {StackelbergAuction} from "../src/StackelbergAuction.sol";
import {EnergyToken} from "../src/EnergyToken.sol";

contract StackelbergAuctionTest is Test {
    StackelbergAuction auction;
    EnergyToken energyToken;

    address payable seller = payable(address(0x1234));
    address buyer1 = address(0xBEEF);
    address buyer2 = address(0xCAFE);

    function setUp() public {
        //deploy token + auction
        energyToken = new EnergyToken();
        auction = new StackelbergAuction(energyToken);

        //mint token
        energyToken.mint(seller, 1e18);

        // Seller registers and deposits energytokens
        vm.startPrank(seller);
        energyToken.approve(address(auction), 1e18);
        auction.registerSeller(2.1e14); // Register seller with a unit cost of 2.1e14 wei
        auction.depositEnergyTokens(1e18);
        vm.stopPrank();

        //register buyers
        vm.prank(buyer1);
        auction.upsertBuyer(0.08e18, 0.003e18); // demand curve params for small flat

        vm.prank(buyer2);
        auction.upsertBuyer(0.4e18, 0.03e18); // demand curve params for family house
    }

    function testAuctionFlow() public {
        // Flat deposits ETH
        vm.deal(buyer1, 1e18);
        vm.prank(buyer1);
        auction.depositETH{value: 1e18}();

        // Buyer2 deposits ETH
        vm.deal(buyer2, 1e18);
        vm.prank(buyer2);
        auction.depositETH{value: 1e18}();

        // Pre-clear logs
        console.log("== Pre-clearing price logs ==");
        console.log("seller ET @auction wallet:", energyToken.balanceOf(address(auction)));
        console.log("seller ET @seller wallet:", energyToken.balanceOf(seller));
        (, , uint256 depositWei, ) = auction.buyers(buyer1);
        console.log("buyer1 depositWei:", depositWei);
        (, , depositWei, ) = auction.buyers(buyer2);
        console.log("buyer2 depositWei:", depositWei);

        //clear the auction
        vm.prank(seller);
        auction.clearAuction();
        console.log("== Clearing price logs ==");
        // DEBUG: log clearing results
        console.log("Clearing price (wei):", auction.clearingPriceWei());
        console.log("Total allocated:", auction.totalAllocated());
        console.log("Buyer1 tokens:", energyToken.balanceOf(buyer1));
        console.log("Buyer2 tokens:", energyToken.balanceOf(buyer2));
        console.log("totalPaidWei:", auction.totalPaidWei());
        console.log("Seller ETH after:", seller.balance);
        console.log(
            "tokens left in auction:",
            energyToken.balanceOf(address(auction))
        );

        //Verify auction cleared
        assertGt(auction.clearingPriceWei(), 0, "price==0");
        assertGt(auction.totalAllocated(), 0, "totalAllocated==0");

        //Check buyers got some tokens
        assertGt(energyToken.balanceOf(buyer1), 0, "buyer1 tokens==0");
        assertGt(energyToken.balanceOf(buyer2), 0, "buyer2 tokens==0");

        assertGt(auction.totalPaidWei(), 0, "totalPaidWei==0");

        //Seller should receive ETH
        assertGt(address(seller).balance, 0, "seller balance==0");
    }
}

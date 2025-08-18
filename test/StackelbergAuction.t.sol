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
        auction = new StackelbergAuction(energyToken, address(0x999));

        //delploy auction with dummy oracle address
        energyToken.mint(seller, 100e18);

        // Seller registers and deposits energytokens
        vm.startPrank(seller);
        energyToken.approve(address(auction), 100e18);
        auction.registerSeller(1e16); // Register seller with a unit cost of 1 ether
        auction.depositEnergyTokens(100e18);
        vm.stopPrank();

        //register buyers
        vm.prank(buyer1);
        auction.upsertBuyer(100e18, 10e18); // demand curve params

        vm.prank(buyer2);
        auction.upsertBuyer(200e18, 20e18); // demand curve params
    }

    function testAuctionFlow() public {
        // Buyer deposits ETH
        vm.deal(buyer1, 1000e18);
        vm.prank(buyer1);
        auction.depositETH{value: 500e18}();

        // Buyer2 deposits ETH
        vm.deal(buyer2, 1000e18);
        vm.prank(buyer2);
        auction.depositETH{value: 700e18}();

        // Pre-clear logs
        console.log("== Pre-clear ==");
        console.log("seller ET @auction:", energyToken.balanceOf(address(auction)));
        console.log("seller ET @seller :", energyToken.balanceOf(seller));
        (, , uint256 depositWei, ) = auction.buyers(buyer1);
        console.log("buyer1 depositWei:", depositWei);
        (, , depositWei, ) = auction.buyers(buyer2);
        console.log("buyer2 depositWei:", depositWei);

        //clear the auction
        vm.prank(seller);
        auction.clearAuction();

        // DEBUG: log clearing results
        console.log("Clearing price (wei):", auction.clearingPriceWei());
        console.log("Total allocated:", auction.totalAllocated());
        console.log("Buyer1 tokens:", energyToken.balanceOf(buyer1));
        console.log("Buyer2 tokens:", energyToken.balanceOf(buyer2));
        console.log("totalPaidWei:", auction.totalPaidWei());
        console.log("Seller ETH after:", seller.balance);
        console.log("tokens left in auction:", energyToken.balanceOf(address(auction)));

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

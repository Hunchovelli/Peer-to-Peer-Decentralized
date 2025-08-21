// test/Gas.t.sol
pragma solidity ^0.8.18;
import "forge-std/Test.sol";
import "../src/StackelbergAuction.sol";
import "../src/EnergyToken.sol";

contract GasTest is Test {
    StackelbergAuction auction;
    EnergyToken t;
    address seller = address(0xBEEF);

    function setUp() public {
        // deploy fresh contracts so state is clean
        t = new EnergyToken();
        auction = new StackelbergAuction(t);
        vm.deal(seller, 100 ether);
        vm.startPrank(seller);
    }

    function testGas_mint_once() public {
        t.mint(seller, 1 ether);
    }

    function testGas_depositEnergyTokens_once() public {
        // set any required approvals/params first
        auction.depositEnergyTokens(1e18);
    }
}

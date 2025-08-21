// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "forge-std/console.sol"; //for debugging

contract StackelbergAuction {
    //using FunctionsRequest for FunctionsRequest.Request; //attach all functions from the FunctionRequest library to the FunctionsRequest.Request struct

    using SafeERC20 for IERC20; //apply the Safe Wrapper to each IERC20 method

    uint256 private constant WAD = 1e18; //used to scale

    IERC20 public immutable energyToken; //reference to the energy token

    uint64 public subscriptionId; // Chainlink subscription ID for the oracle
    bytes32 public donId = keccak256("fun-ethereum-sepolia-1"); //Sepolia DON ID

    /*Oracle results
    bytes32 public latestRequestId; // The latest request ID from the oracle
    bytes public latestResult; // The latest result from the oracle
    bytes public latestError; // The latest error from the oracle
    uint256 public latestNetW; // The latest net capacity in WAD*/

    uint256 public sampleIntervalSec = 300; // default 5 minutes

    struct Seller {
        address addr; //address of the seller
        uint256 unitCostWei; //marginal cost per kWh in wei
        bool active; // true if the seller is active
    }

    struct Buyer {
        uint256 a; //intercept for q_i - how much energy the buyer would take it if was free
        uint256 b; //price senstivity, how quick the demand drops with an increase in price from the seller
        uint256 depositWei; // escrowed ETH
        bool active; // true if the buyer is active
    }

    Seller public seller; // the seller in the auction
    mapping(address => Buyer) public buyers; // mapping of buyer addresses to their Buyer structs
    address[] public buyerList; // list of buyers as their addresses

    //Auction state
    bool public auctionLocked; // flag to indicate if the auction is locked
    uint256 public clearingPriceWei; // Buyers can see what price the auction ended at (wei per kWh (WAD scaled))
    uint256 public totalAllocated; // The total quantity of energy that was successfully allocated to buyers in the auction (kWh (WAD scaled))
    uint256 public totalPaidWei; // The total amount of ETH that was paid by buyers to sellers in the auction

    event CapacityUpdated(uint256 newCapacityWad); // emits the log of the sellers capacity updated
    event OracleUpdated(address newOracle); //emits the log of the oracle address updated
    event SellerRegistered(address indexed seller, uint256 unitCostWei); // emits the log of registering the sellers address and unit cost per wei
    event SellerTokenDeposit(uint256 amount); // emits the log of a seller depositing Energy tokens
    event SellerTokenWithdrawal(uint256 amount); // emits the log of a seller withdrawing Energy tokens
    event BuyerRegistered(address indexed buyer, uint256 a, uint256 b); // emits the log of a buyer registering
    event DepositETH(address indexed buyer, uint256 amountWei); // emits the log of a buyer depositing ETH
    event WithdrawETH(address indexed buyer, uint256 amountWei); // emits the log of a buyer withdrawing ETH
    event AuctionCleared(uint256 priceWei, uint256 totalQ); // emits the log of the final auction price and total quantity cleared
    event Allocation(address indexed buyer, uint256 q, uint256 paidWei); // emits the log of a buyer's allocation in terms of quantity collected and amount paid
    event Payout(address indexed seller, uint256 revenueWei); // emits the log of a seller's payout
    /*event OracleRequested(bytes32 requestId);
    event OracleFulfilled(bytes32 requestId, uint256 netW, uint256 mintedWad);
    event CapacityPulled(uint256 amountWad);
    event SampleIntervalUpdated(uint256 seconds_);*/
    modifier onlySeller() {
        require(
            msg.sender == seller.addr,
            "Only the seller can call this function"
        ); //modifier to restrict access to the seller
        _;
    }

    /*modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle");
        _; // Continue with the function execution
    }*/

    modifier notLocked() {
        require(!auctionLocked, "Auction is locked"); //modifier to restrict access when auction is locked
        _;
    }

    constructor(IERC20 _energyToken) {
        // constructor to initialize the contract with the EnergyToken address
        require(address(_energyToken) != address(0), "Invalid token address"); // Check for valid token address
        //require(oracle != address(0), "Invalid oracle address"); // Check for valid oracle address
        energyToken = _energyToken; // Set the energy token
        /*subscriptionId = _subId; // Set the Chainlink subscription ID
        donId = _donId; // Set the DON ID*/
    }

    /*function setSampleInterval(uint256 seconds_) external {
        require(seconds_ > 0, "bad interval");
        sampleIntervalSec = seconds_;
        emit SampleIntervalUpdated(seconds_);
    }

    function setCallbackGas(uint32 gasLimit) external {
        callbackGasLimit = gasLimit;
    }

    function requestNetPower(
        bytes memory sourceCode,
        string[] memory args
    ) external {
        FunctionRequest.Request memory req;
        req.initializeRequest(
            FunctionsRequest.Location.Inline,
            FunctionsRequest.CodeLanguage.JavaScript,
            sourceCode
        );
        if (args.length > 0) {
            req.setArgs(args);
        }

        bytes32 reqId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            callbackGasLimit,
            donId
        );
        latestRequestId = reqId; // Store the request ID
        emit OracleRequested(reqId); // Emit an event for the request
    }

    function fufillRequest(
        bytes32 requestID,
        bytes memory response,
        bytes memory err
    ) internal override {
        latestResponse = response;
        latestError = err;

        if (err.length != 0) return;

        uint256 netW = abi.decode(response, (uint256));
        latestNetW = netW;

        uint256 mintedWad = _wattsToKwhWad(netW, sampleIntervalSec);

        if (seller.active && mintedWad > 0) {
            energyToken.mint(seller.addr, mintedWad);

            // If the seller is active and there is a positive minted amount
            if (
                energyToken.allowance(seller.addr, address(this)) >= mintedWad
            ) {
                // If the allowance is less than the minted amount, set it to the minted amount
                energyToken.safeTransferFrom(
                    seller.addr,
                    address(this),
                    mintedWad
                );
                emit CapacityPulled(mintedWad); // Emit an event for the capacity pulled
            }
        }
        emit OracleFulfilled(requestID, netW, mintedWad); // Emit an event for the oracle fulfillment
    }*/

    function registerSeller(uint256 unitCostWeiPerKWhWad) external notLocked {
        //only executes if the auction is not locked
        require(!seller.active, "Seller is already registered"); //ensures the seller is not already registered
        require(
            unitCostWeiPerKWhWad > 0,
            "Unit cost must be greater than zero"
        ); //ensures the unit cost is greater than zero
        seller = Seller({
            addr: msg.sender,
            unitCostWei: unitCostWeiPerKWhWad,
            active: true
        }); //registers the seller
        energyToken.approve(address(this), type(uint256).max);
        emit SellerRegistered(msg.sender, unitCostWeiPerKWhWad); //emits the log of registering the sellers address and unit cost per wei
    }

    function updateCapacity(uint256 netWad) external onlySeller notLocked {
        require(seller.active, "No seller"); // Ensures the seller is registered
        require(netWad > 0, "No surplus"); // Ensures the net capacity is greater than zero to check the seller has surplus

        energyToken.safeTransferFrom(seller.addr, address(this), netWad); // Transfers energy tokens from the seller to the contract

        emit CapacityUpdated(netWad); //emits the log of the new capacity
    }

    function depositEnergyTokens(uint256 amount) external onlySeller notLocked {
        //only executes if the seller calls this function and auction is not locked
        require(amount > 0, "Amount must be greater than zero"); //ensures the amount is greater than zero
        energyToken.safeTransferFrom(msg.sender, address(this), amount); // Transfers energy tokens from the seller to the contract
        emit SellerTokenDeposit(amount); //emits the log of a seller depositing Energy tokens
    }

    function withdrawEnergyTokens(
        uint256 amount
    ) external onlySeller notLocked {
        //only executes if the seller calls it and auction is not locked
        energyToken.safeTransfer(msg.sender, amount); // Transfers specified amount of energy tokens from the contract to the seller
        emit SellerTokenWithdrawal(amount); //emits the log of a seller withdrawing Energy tokens
    }

    function capacity() public view returns (uint256) {
        return energyToken.balanceOf(address(this)); // Returns the balance of energy tokens held by the contract
    }

    function upsertBuyer(uint256 a, uint256 b) external notLocked {
        // Updates or inserts the buyer information if the auction is not locked
        require(a > 0, "a must be greater than zero"); //ensures the intercept is greater than zero
        require(b > 0, "b must be greater than zero"); //ensures the slope is greater than zero
        Buyer storage br = buyers[msg.sender]; // Get the buyers struct and store it in storage
        if (!br.active) {
            // Check if the buyer is not already registered
            br.active = true; // Mark the buyer as active
            buyerList.push(msg.sender); // Push the buyer's address to the list
        }
        br.a = a; // Update the intercept
        br.b = b; // Update the  slope
        emit BuyerRegistered(msg.sender, a, b); // Emit the BuyerRegistered event
    }

    function depositETH() external payable notLocked {
        // Allows buyers to deposit ETH into the contract
        require(buyers[msg.sender].active, "Buyer is not registered"); // Ensure the buyer is registered
        require(msg.value > 0, "Deposit must be greater than zero"); // Ensure the deposit is greater than zero
        buyers[msg.sender].depositWei += msg.value; // Update the buyer's deposit
        emit DepositETH(msg.sender, msg.value); // Emit the DepositETH event
    }

    function withdrawETH(uint256 amount) external notLocked {
        Buyer storage br = buyers[msg.sender]; // Get the buyer's struct
        require(br.active, "Buyer is not registered"); // Ensure the buyer is registered
        require(amount > 0 && amount <= br.depositWei, "Insufficient balance"); // Ensure the withdrawal amount is valid
        br.depositWei -= amount; // Update the buyer's deposit
        (bool ok, ) = msg.sender.call{value: amount}(""); // Attempt to transfer the ETH back to the buyer
        require(ok, "Transfer failed"); // Ensure the transfer was successful
        emit WithdrawETH(msg.sender, amount); // Emit the WithdrawETH event
    }

    function clearAuction() external notLocked {
        // processes the Auction
        require(seller.active, "no seller"); // Ensure the seller is registered
        require(buyerList.length > 0, "no buyers"); // Ensure there are registered buyers
        uint256 cap = capacity(); // Get the current capacity of energy
        require(cap > 0, "no capacity"); // Ensure there is capacity

        auctionLocked = true; // Lock the auction

        (uint256 sumA, uint256 sumB) = _sumAB(); // Get the sum of A and B and store it in the respective variables
        require(sumB > 0, "sumB=0"); // Ensure the sum of B is greater than zero

        console.log("sumA:", sumA);
        console.log("sumB:", sumB);
        console.log("sellerCost:", seller.unitCostWei);

        //Unconstrained p0 = (SumA/2*SumB) + c/2 - for maximum profit for seller with no constraints
        uint256 frac = _divW(sumA, 2 * sumB);
        uint256 p0 = _add(frac, seller.unitCostWei / 2);
        uint256 q0 = _zeroFloor(_sub(sumA, _mulW(sumB, p0))); // Calculate the total quantity for maximum profit

        uint256 pStar = p0; //optimal monopoly price
        uint256 qStar = q0; //optimal monopoly quantity

        console.log("frac:", frac);
        console.log("p0:", p0);
        console.log("q0:", q0);

        if (q0 == 0) {
            //Quantity is Zero when demand curve hits the x axis and there is a choke price
            uint256 pChoke = _divW(sumA, sumB);
            if (pChoke < seller.unitCostWei) {
                // checks if the price choke (price) is less than the seller unit cost
                pChoke = seller.unitCostWei; // if it is, set it to the seller's unit cost so the seller can at least break even
            }
            pStar = pChoke; // Set the optimal monopoly price to the choke price
            qStar = 0; // Set the optimal monopoly quantity to zero
        } else if (q0 > cap) {
            // If the optimal quantity is greater than the capacity, we have to adjust the price to bring the optimal quantity back to the capacity
            uint256 num = _zeroFloor(_sub(sumA, cap)); //the numerator of the price adjustment formula to bring the optimal quantity back to the capacity
            uint256 pcap = _divW(num, sumB); //the price adjustment formula executed
            if (pcap < seller.unitCostWei) {
                pcap = seller.unitCostWei; // If the price adjustment is less than the seller's unit cost, set it to the seller's unit cost so the seller can be profitable
            }
            pStar = pcap; //sets the optimal monopoly price to the price at capacity
            qStar = _zeroFloor(_sub(sumA, _mulW(sumB, pStar))); // Set the optimal monopoly quantity to the capacity
            if (qStar > cap) {
                qStar = cap; // Ensure the optimal quantity does not exceed the capacity
            }
        }

        clearingPriceWei = pStar; //set the clearing price to the optimal monopoly price
        totalAllocated = qStar; //set the total allocated quantity to the optimal monopoly quantity
        emit AuctionCleared(pStar, qStar); //Emit the AuctionCleared event using local variables which is cheaper on gas

        uint256 totalDemandAtP; // Total demand at some p
        uint256[] memory q = new uint256[](buyerList.length); // Quantity allocated to each buyer
        for (uint256 i = 0; i < buyerList.length; i++) {
            Buyer storage br = buyers[buyerList[i]]; // Get the buyer's struct
            if (!br.active) {
                // Check if the buyer is not active
                continue; //skip this loop iteration and jump to the next element in the list
            }
            uint256 qi = _zeroFloor(_sub(br.a, _mulW(br.b, pStar))); // Calculate the quantity allocated to the buyer
            q[i] = qi; // Store the quantity in the array
            totalDemandAtP += qi; // Add the quantity to the total demand at the clearing price
        }
        if (totalDemandAtP == 0) return; // If there is no demand at the clearing price, exit the function

        uint256 revenue; // Total revenue generated at the clearing price
        uint256 tokensLeft = cap; //the amount of tokens available to give to buyers

        for (uint256 i = 0; i < buyerList.length; i++) {
            address user = buyerList[i]; // Get the buyer's address
            Buyer storage br2 = buyers[user]; // Gets the buyer struct
            if (!br2.active) continue; // checks if the buyer is active

            uint256 qi = q[i]; // Get the quantity allocated to the buyer
            if (qi == 0) continue; // If the quantity is zero, skip to the next buyer

            uint256 alloc = (qStar < totalDemandAtP)
                ? (qi * qStar) / totalDemandAtP
                : qi; // Calculate the allocation for the buyer based on the buyers percentage of the total demand at the clearing price. Keeps each buyers share proportional

            uint256 costWei = _mulWei(alloc, pStar); // Calculate the cost in wei for the allocated quantity
            if (costWei > br2.depositWei) {
                // If the cost exceeds the buyer's deposit, adjust the allocation
                alloc = _divWei(br2.depositWei, pStar); // Adjust the allocation of energy to the buyer's deposit
                costWei = _mulWei(alloc, pStar); // Calculate the new cost in wei for the adjusted allocation
            }

            if (alloc == 0) continue; // Skip buyers who cant afford the smallest unit or whose proportional shares works out to 0

            if (alloc > tokensLeft) {
                alloc = tokensLeft; // Adjust the allocation to the tokens left
                costWei = _mulWei(alloc, pStar); // Calculate the new cost in wei for the adjusted allocation
            }

            if (alloc == 0) continue; //  buyer was last in line and tokensLeft is 0 as supply ran out.

            br2.depositWei -= costWei; // Deduct the cost from the buyer's deposit
            revenue += costWei; // Add the cost to the total revenue
            tokensLeft -= alloc; // Subtract the allocated tokens from the total tokens left

            energyToken.safeTransfer(user, alloc);
            emit Allocation(user, alloc, costWei);

            if (tokensLeft == 0) {
                // If there are no tokens left, break the loop
                break;
            }
        }

        if (revenue > 0) {
            totalPaidWei = revenue; //store it in the state variable
            (bool ok, ) = seller.addr.call{value: revenue}(""); // Transfer the revenue to the seller
            require(ok, "Transfer failed"); // Ensure the transfer was successful
            emit Payout(seller.addr, revenue); // Emit the payout event
        }
    }

    function buyersCount() external view returns (uint256) {
        return buyerList.length;
    }

    function previewPrice()
        external
        view
        returns (uint256 priceWei, uint256 qTotal)
    {
        if (!seller.active || buyerList.length == 0) {
            return (0, 0); // If there is no seller or no buyers, return zero price and quantity
        }
        uint256 cap = capacity(); // Get the auction capacity
        if (cap == 0) return (0, 0); // If the capacity is zero, return zero price and quantity
        (uint256 sumA, uint256 sumB) = _sumAB(); // Get the sum of A and B
        if (sumB == 0) return (0, 0); // If the sum of B is zero, return zero price and quantity

        uint256 p0 = _add(
            _divW(_sumFrac(sumA, 2 * sumB), seller.unitCostWei / 2),
            seller.unitCostWei / 2
        ); // Calculate the initial price
        uint256 q0 = _zeroFloor(_sub(sumA, _mulW(sumB, p0))); // Calculate the initial quantity

        if (q0 == 0) {
            uint256 pChoke = _divW(sumA, sumB); // Calculate the choke price
            if (pChoke < seller.unitCostWei) {
                pChoke = seller.unitCostWei; // If the choke price is less than the seller's unit cost, set it to the seller's unit cost
            }
            return (pChoke, 0); // Return the choke price and zero quantity
        } else if (q0 > cap) {
            uint256 num = _zeroFloor(_sub(sumA, cap)); // Calculate the numerator for the price adjustment
            uint256 pcap = _divW(num, sumB); // Calculate the price at cap
            if (pcap < seller.unitCostWei) pcap = seller.unitCostWei; // If the price at cap is less than the seller's unit cost, set it to the seller's unit cost
            uint256 qStar = _zeroFloor(_sub(sumA, _mulW(sumB, pcap))); // Calculate the quantity at cap
            if (qStar > cap) {
                qStar = cap; // Ensure the quantity does not exceed the capacity
            }
            return (pcap, qStar); // Return the price at cap and the quantity at cap
        } else {
            return (p0, q0); // Return the initial price and quantity
        }
    }

    function _sumAB() internal view returns (uint256 sumA, uint256 sumB) {
        for (uint256 i = 0; i < buyerList.length; i++) {
            Buyer storage br = buyers[buyerList[i]]; // Get the buyer's struct
            if (!br.active) continue; // Skip inactive buyers
            sumA += br.a; // Accumulate the value of A
            sumB += br.b; // Accumulate the value of B
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    } // Add two numbers

    function _sub(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? a - b : 0;
    } // Subtract two numbers only if a > b else 0

    function _mulW(uint256 x, uint256 y) private pure returns (uint256) {
        return (x * y) / WAD;
    } // Multiply two numbers with WAD scaling

    function _divW(uint256 x, uint256 y) private pure returns (uint256) {
        require(y != 0, "div0");
        return (x * WAD) / y;
    } // Divide two numbers with WAD scaling

    function _mulWei(
        uint256 qtyWad,
        uint256 priceWeiPerWad
    ) private pure returns (uint256) {
        return (qtyWad * priceWeiPerWad) / WAD;
    } // Multiply quantity and price with WAD scaling

    function _divWei(
        uint256 weiAmt,
        uint256 priceWeiPerWad
    ) private pure returns (uint256) {
        require(priceWeiPerWad != 0, "div0");
        return (weiAmt * WAD) / priceWeiPerWad;
    } // Divide wei amount by price with WAD scaling. Denominator can't be 0

    function _sumFrac(uint256 num, uint256 den) private pure returns (uint256) {
        require(den != 0, "div0");
        return (num * WAD) / den;
    } // Calculate the fraction of two numbers with WAD scaling. Denominator can't be 0

    function _zeroFloor(uint256 x) private pure returns (uint256) {
        return x;
    } // Return the value as is and zero is the minimum the function can go to
}

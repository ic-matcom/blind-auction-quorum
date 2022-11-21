// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

struct BidID {
    uint percent;
    uint id;
}

function sort(BidID[] storage arr){
    if (arr.length > 1)
        quickSort(arr, 0, arr.length - 1);
}

function compareLess(BidID memory a, BidID memory b) pure returns (bool) {
    if(a.percent == b.percent)
        return a.id < b.id;
    return a.percent < b.percent;
}

function quickSort(BidID[] memory arr, uint left, uint right){
    if (left >= right)
        return;
    BidID memory p = arr[(left + right) / 2];   // p = the pivot element
    uint i = left;
    uint j = right;
    while (i < j) {
        while (compareLess(arr[i],p)) ++i;
        while (compareLess(p,arr[j])) --j;         // arr[j] > p means p still to the left, so j > 0
        if (compareLess(arr[j],arr[i]))
            (arr[i], arr[j]) = (arr[j], arr[i]);
        else
            ++i;
    }

    // Note --j was only done when a[j] > p.  So we know: a[j] == p, a[<j] <= p, a[>j] > p
    if (j > left)
        quickSort(arr, left, j - 1);    // j > left, so j > 0
    quickSort(arr, j + 1, right);
}

contract BlindAuction {
    struct Bid {
        bytes32 blindedBid;
        uint deposit;
    }

    struct BidRevealed {
        address addressBidder;
        uint amount;
        uint percent;
    }

    // struct BidID {
    //     uint percent;
    //     uint id;
    // }


    address payable public beneficiary;
    uint public boneTotal;
    uint public biddingEnd;
    uint public revealEnd;
    bool public ended;
    
    mapping(address => Bid[]) public bids;
    BidRevealed[] public bidsRevealed;
    BidID[] public bidsRevealedPercentID;

    // Allowed withdrawals of previous bids
    mapping(address => uint) pendingReturns;

    event AuctionEnded(BidRevealed[] winners, uint percentToPay);

    // Errors that describe failures.

    /// The function has been called too early.
    /// Try again at `time`.
    error TooEarly(uint time);
    /// The function has been called too late.
    /// It cannot be called after `time`.
    error TooLate(uint time);
    /// The function auctionEnd has already been called.
    error AuctionEndAlreadyCalled();

    // Modifiers are a convenient way to validate inputs to
    // functions. `onlyBefore` is applied to `bid` below:
    // The new function body is the modifier's body where
    // `_` is replaced by the old function body.
    modifier onlyBefore(uint time) {
        if (block.timestamp >= time) revert TooLate(time);
        _;
    }
    modifier onlyAfter(uint time) {
        if (block.timestamp <= time) revert TooEarly(time);
        _;
    }

    constructor(
        uint boneToSale,
        uint biddingTime,
        uint revealTime,
        address payable beneficiaryAddress
    ) {
        boneTotal = boneToSale;
        beneficiary = beneficiaryAddress;
        biddingEnd = block.timestamp + biddingTime;
        revealEnd = biddingEnd + revealTime;
    }

    /// Place a blinded bid with `blindedBid` =
    /// keccak256(abi.encodePacked(value, percent, secret)).
    /// The same address can place multiple bids.
    function bid(bytes32 blindedBid)
        external
        payable
        onlyBefore(biddingEnd)
    {
        bids[msg.sender].push(Bid({
            blindedBid: blindedBid,
            deposit: msg.value
        }));
    }

    function blind_a_bid(uint value, uint percent, bytes32 secret) 
      public pure returns (bytes32){
        return keccak256(abi.encodePacked(value, percent, secret));
    }

    /// Reveal your blinded bids. You will get a refund for all
    /// correctly blinded invalid bids and for all bids except for
    /// the winners bids.
    function reveal(
        uint[] calldata values,
        uint[] calldata percents,
        bytes32[] calldata secrets
    )
        external
        onlyAfter(biddingEnd)
        onlyBefore(revealEnd)
    {
        bidsRevealed[0] = BidRevealed({
            addressBidder: msg.sender,
            amount: 0,
            percent: 0
        });
        uint length = bids[msg.sender].length;
        require(values.length == length);
        require(percents.length == length);
        require(secrets.length == length);

        for (uint i = 0; i < length; i++) {
            Bid storage bidToCheck = bids[msg.sender][i];

            // Its offers have already been previously revealed
            if(bidToCheck.blindedBid == bytes32(0)){
                return;
            }
            pendingReturns[msg.sender] += bidToCheck.deposit;

            (uint value, uint percent, bytes32 secret) =
              (values[i], percents[i], secrets[i]);
            if (bidToCheck.blindedBid != blind_a_bid(value, percent, secret)) {
                // Bid was not actually revealed.
                bidToCheck.blindedBid = bytes32(0);
                continue;
            }
            if (pendingReturns[msg.sender] >= value) {
                uint _id = bidsRevealed.length;
                bidsRevealed.push(BidRevealed({
                  addressBidder : msg.sender,
                  amount : value,
                  percent : percent
                }));
                bidsRevealedPercentID.push(BidID({
                  percent : percent,
                  id : _id
                }));
                pendingReturns[msg.sender] -= value;
            }
            // Make it impossible for the sender to re-claim
            // the same deposit.
            bidToCheck.blindedBid = bytes32(0);
        }
    }

    /// Withdraw a bids invalid and not winning bids.
    function withdraw() external {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `transfer` returns (we implement a conditions → actions (effects) 
            // → interaction design pattern that prevents such unwanted behavior.).
            pendingReturns[msg.sender] = 0;

            payable(msg.sender).transfer(amount);
        }
    }

    /// End the auction and send transaction to the beneficiary.
    function auctionEnd()
        external
        onlyAfter(revealEnd)
    {
        if (ended) revert AuctionEndAlreadyCalled();

        // sort bids and choose winners

        sort(bidsRevealedPercentID);

        BidRevealed[] memory winnersAuction;

        uint percentToPay;
        uint sumBids = 0;
        uint length = bidsRevealedPercentID.length;
        for(uint i = 0;i < length;i++){
            BidRevealed storage bidActual = bidsRevealed[bidsRevealedPercentID[i].id];
            if(sumBids < boneTotal){
                if(sumBids + bidActual.amount >= boneTotal){
                    percentToPay = bidActual.percent;

                    uint exceed = sumBids + bidActual.amount - boneTotal;
                    bidActual.amount -= exceed;

                    pendingReturns[bidActual.addressBidder] += exceed;

                    winnersAuction = new BidRevealed[](i + 1);

                    for(uint j = 0;j <= i + 1;j++){
                        BidRevealed storage bidAux = bidsRevealed[bidsRevealedPercentID[j].id];
                        winnersAuction[j] = BidRevealed(bidAux.addressBidder, uint256(bidAux.amount), uint256(bidAux.percent));
                    }
                }

                sumBids += bidActual.amount;
            }
            else{
                pendingReturns[bidActual.addressBidder] += bidActual.amount;
            }
        }
        emit AuctionEnded(winnersAuction, percentToPay);

        ended = true;
        beneficiary.transfer(sumBids);
    }

}
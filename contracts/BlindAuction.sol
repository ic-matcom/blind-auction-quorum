// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract BlindAuction{
    struct BidID {
        uint percent;
        uint id;
    }

    function sort(BidID[] storage data) internal {
        if(data.length > 1)
            quickSort(data, int(0), int(data.length - 1));
    }
    
    function compareLess(BidID memory a, BidID memory b) pure internal returns (bool) {
        if(a.percent == b.percent)
            return a.id < b.id;
        return a.percent < b.percent;
    }

    function quickSort(BidID[] storage arr, int left, int right) internal{
        int i = left;
        int j = right;
        if(i==j) return;
        BidID memory pivot = arr[uint(left + right) / 2];
        BidID memory tmp;
        while (i <= j) {
            while (compareLess(arr[uint(i)],pivot)) i++;
            while (compareLess(pivot,arr[uint(j)])) j--;
            if (i <= j) {
                tmp = arr[uint(j)];
                arr[uint(j)] = arr[uint(i)];
                arr[uint(i)] = tmp;
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }

    struct Bid {
        bytes32 blindedBid;
        uint deposit;
    }

    struct BidRevealed {
        address addressBidder;
        uint amount;
        uint percent;
    }

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

    event AuctionEnded(BidRevealed[] winners, uint sumBids, uint percentToPay);

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
        return keccak256(abi.encode(value, percent, secret));
    }

    // function only for test
    function bidsRevealedPercentID_len() public view returns (uint){
        return bidsRevealedPercentID.length;
    }

    // function only for test
    function bidsRevealed_len() public view returns (uint){
        return bidsRevealed.length;
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
                    uint exceed = sumBids + bidActual.amount - boneTotal;
                    bidActual.amount -= exceed;

                    pendingReturns[bidActual.addressBidder] += exceed;

                    winnersAuction = new BidRevealed[](i + 1);

                    percentToPay = bidActual.percent;

                    for(uint j = 0;j <= i;j++){
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

        // if sum bids no exceed boneTotal, all bids are winners
        if(sumBids < boneTotal && length > 0){
            winnersAuction = new BidRevealed[](length);

            percentToPay = bidsRevealed[bidsRevealedPercentID[length - 1].id].percent;

            for(uint j = 0;j < length;j++){
                BidRevealed storage bidAux = bidsRevealed[bidsRevealedPercentID[j].id];
                winnersAuction[j] = BidRevealed(bidAux.addressBidder, uint256(bidAux.amount), uint256(bidAux.percent));
            }
        }
        emit AuctionEnded(winnersAuction, sumBids, percentToPay);

        ended = true;
        beneficiary.transfer(sumBids);
    }

}
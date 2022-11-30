from brownie import BlindAuction, accounts, chain, config
from .tools import wait_chain
from random import randint

# 2 bidders and 2 bids
def auction_random():
    #Arrange

    #Act
    blind_auction = BlindAuction.deploy(randint(10**3,10**5), 
      randint(30,60), randint(30,60), accounts[0],
      {"from" : accounts[0]})
    
    # bid
    bidders = randint(3,12)
    bids = []
    [bids.append([]) for i in range(bidders)]
    for i in range(bidders):
        for j in range(randint(1,8)):
            value = randint(10,10**4)
            percent = randint(1,1000)
            secret_key = config["secrets"][f"acc{i}"]
            hash = blind_auction.blind_a_bid(value,percent,secret_key)

            bids[i].append((value,percent,secret_key))

            blind_auction.bid(hash, {"from" : accounts[i + 1], "amount" : randint(max(value - 100,0),value + 100)})

    wait_chain(chain, blind_auction.biddingEnd(), "Waiting for bidding end")

    stats_revealBid = open("stats_revealBid",'a')
    for i in range(bidders):
        values = [j for j,k,l in bids[i]]
        percents = [k for j,k,l in bids[i]]
        secrets = [l for j,k,l in bids[i]]
        tx_reveal = blind_auction.reveal(values,percents,secrets,{"from" : accounts[i + 1]})

        stats_revealBid.write(str(len(bids[i])) + " " + str(tx_reveal.gas_used) + "\n")
        
    wait_chain(chain, blind_auction.revealEnd(), "Waiting for reveal end")

    assert(blind_auction.bidsRevealedPercentID_len() == blind_auction.bidsRevealed_len())

    tx_end = blind_auction.auctionEnd({"from" : accounts[0]})

    # print(tx_end.gas_used)
    print(tx_end.events)
    print(blind_auction.boneTotal())

    stats_auctionEnd = open("stats_auctionEnd",'a')
    stats_auctionEnd.write(str(blind_auction.bidsRevealed_len()) + " " + str(tx_end.gas_used) + "\n")

    # stats_auctionEnd = open("stats_auctionEnd",'a')
    for i in range(bidders):
        balance_tmp = accounts[i + 1].balance()
        tx_withdraw = blind_auction.withdraw({"from" : accounts[i + 1]})

        assert(balance_tmp <= accounts[i + 1].balance())

    #Assert
    assert(tx_end.events['AuctionEnded']['sumBids'] <= blind_auction.boneTotal())

def main():
    auction_random()

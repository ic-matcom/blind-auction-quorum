from brownie import BlindAuction, accounts, chain, config
from .tools import wait_chain

# 2 bidders and 2 bids
def auction1():
    #Arrange
    account = accounts[0]

    #Act
    blind_auction = BlindAuction.deploy(100, 3, 3, 
      accounts[1],
      {"from" : account})
    
    hash1 = blind_auction.blind_a_bid(100,100,config["secrets"]["acc0"])
    hash2 = blind_auction.blind_a_bid(100,50,config["secrets"]["acc1"])

    blind_auction.bid(hash1,{"from" : accounts[2], "amount" : 100})
    blind_auction.bid(hash2,{"from" : accounts[3], "amount" : 100})

    wait_chain(chain, blind_auction.biddingEnd(), "Waiting for bidding end")

    blind_auction.reveal([100],[100],[config["secrets"]["acc0"]],{"from" : accounts[2]})
    blind_auction.reveal([100],[50],[config["secrets"]["acc1"]],{"from" : accounts[3]})

    wait_chain(chain, blind_auction.revealEnd(), "Waiting for reveal end")

    tx_end = blind_auction.auctionEnd({"from" : accounts[0]})

    #Assert
    assert(tx_end.events['AuctionEnded']['percentToPay'] == 50)
    # print(blind_auction.bidsRevealedPercentID())

def main():
    auction1()
from brownie import accounts, config, BlindAuction

def deploy_blind_auction():
    # example account
    account = accounts[0]
    # account manually created and encrypted for brownie
    # account = accounts.load("test-account")

    # from enviroment local variable
    # account = accounts.add(os.getenv("PRIVATE_KEY"))
    # account = accounts.add(config["wallets"]["from_key"])
    
    blind_auction = BlindAuction.deploy(100, 60, 60, 
      "0x33A4622B82D4c04a53e170c638B944ce27cffce3",
      {"from" : account})

    blind1 = blind_auction.blind_a_bid(10,5,"11111111111111111111111111111111")

    print(blind1)
    print(blind_auction.blind_a_bid(10,6,"11111111111111111111111111111111"))

def main():
    deploy_blind_auction()
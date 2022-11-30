
def wait_chain(chain, until : int, message = "Waiting ..."):
    while(chain.time() < until + 1):
        print(message)
        chain.sleep(1)


const path = require('path');
const fs = require('fs');
const solc = require('solc');

const AuctionPath = path.resolve(__dirname, 'contracts', 'solidity.sol');
const source = fs.readFileSync(AuctionPath, 'utf8')

var input = {
    language: 'Solidity',
    sources: {
        'solidity.sol' : {
            content: source
        }
    },
    settings: {
        optimizer: {
            enabled: true
        },
        outputSelection: {
            '*':{
                '*':['*']
            }
        }
    }
}; 

console.log(JSON.parse(solc.compile(JSON.stringify(input))));

// module.exports = solc.compile(source,1).contracts[':BlindAuction'];

// console.log(solc.compile(source,1));

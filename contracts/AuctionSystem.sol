// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <8.10.0;

contract AuctionSystem{
    uint public endTime;
    address payable public beneficiary;
    bool public ended;
    uint public highestPrice;
    address public highester;
    mapping(address=> uint) public returnDict;

    // 变更触发的事件
    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    constructor(uint _endtime, address _beneficiary) {
        endTime = block.timestamp + _endtime;
        beneficiary = payable(_beneficiary);
    }

    function bid() payable public {
        require(block.timestamp < endTime, "Auction time has ended");
        require(msg.value > highestPrice, "Not exceeding the maximum price");
        if (highestPrice > 0) {
            returnDict[highester] += highestPrice; // 重新记录最高价之前，将之前的最高价记录在映射中，已便返回他们的价格
        }
        highestPrice = msg.value;
        highester = msg.sender;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    function priceBack() public returns(bool) {
        uint money = returnDict[msg.sender];
        returnDict[msg.sender] = 0;
        if (money > 0) {
            if (!payable(msg.sender).send(money)){
                returnDict[msg.sender] = money;
                return false;
            }
        }
        return true;
        
    }

    function endAuction() public {
        require(endTime < block.timestamp, "The auction has not ended yet");
        require(!ended);
        beneficiary.transfer(highestPrice);
        ended = true;
        emit AuctionEnded(highester, highestPrice);
    }
}
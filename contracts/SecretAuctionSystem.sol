// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <8.10.0;

contract BlindAuction{
    struct Bid {
        bytes32 blindedBid;  // 盲投标
        uint deposit; // 订金
    }

    address payable public beneficiary; // 受益人
    uint public biddingEnd; // 投标结束时间撮
    uint public revealEnd; // 揭示结束时间撮
    bool public ended; // 竞拍是否结束

    mapping(address => Bid[]) public bids; // 每个地址对应一个出价数组

    address public highestBidder; // 最高价者地址
    uint public highestBid; // 最高出价

    mapping(address=>uint) pendingReturns; //以便将钱返还的一个出价记录映射

    event AuctionEnded(address winner, uint highestBid); // 事件： 拍卖结束

    modifier onlyBefore(uint _time) { require(block.timestamp < _time); _; }
    modifier onlyAfter(uint _time) { require(block.timestamp > _time); _; }

    constructor(uint _biddingTime, uint _revealTime, address payable _beneficiary) {
        beneficiary = _beneficiary; // 受益人
        biddingEnd = block.timestamp + _biddingTime;  // 拍卖结束时间： 当前区块时间 + 拍卖多久
        revealEnd = biddingEnd + _revealTime; // 揭示时间：拍卖结束时间 + 多久揭示
    }

    // 出价: 将出价结构体， push 到出价结构体数组
    function bid(bytes32 _blindedBid) public payable onlyBefore(biddingEnd){
        bids[msg.sender].push(
            Bid({
                blindedBid:_blindedBid, 
                deposit:msg.value
            })
            );
    }

    // 披露
    function reveal(uint[] memory _values, bool[] memory _fake, bytes32[] memory _secret) public onlyAfter(biddingEnd) onlyBefore(revealEnd){
        uint length = bids[msg.sender].length; // 获取出价结构体数组长度
        require(_values.length == length); // 三个参数的对应长度必须跟这个整体结构长度一致（因为出价方法中的 _blindedBid 是通过 这三个值hash得到的）
        require(_fake.length == length); // 三个参数的对应长度必须跟这个整体结构长度一致
        require(_secret.length == length); // 三个参数的对应长度必须跟这个整体结构长度一致
        uint refund; // 退款额
        for (uint i = 1; i< length; i++) {
            Bid storage bidNew = bids[msg.sender][i]; // 获取到每个出价结构体对象
            (uint value, bool fake, bytes32 secret) = (_values[i], _fake[i], _secret[i]); // 再获取到对应的值
            bytes memory v1 = abi.encodePacked(value,fake,secret); 
            if (bidNew.blindedBid != keccak256(v1)) {   // 判断hash后是否相等， 不相等则不继续
                continue;
            }
            refund += bidNew.deposit; // 退款额度累加
            if (!fake&&bidNew.deposit >= value) {
                if (placeBid(msg.sender,value))
                    refund -= value; // 一次退款成功累减
            }
            bidNew.blindedBid = bytes32(0); // 地址重置
        }

        payable(msg.sender).transfer(refund);
    }

    // 披露时才开始真正的竞拍，都不知道到底谁转了多少钱
    function placeBid(address _bidder, uint _value) internal returns (bool success) {
        if (_value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBid = _value;
        highestBidder = _bidder;
        return true;
    }

    function withdraw() public {
        uint amount = pendingReturns[msg.sender];
        if (amount >0) {
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
        }
    }

    function auctionEnd() public onlyAfter(revealEnd) {
        require(!ended);
        emit AuctionEnded(highestBidder, highestBid);
        ended = true;
        beneficiary.transfer(highestBid);
    }
}
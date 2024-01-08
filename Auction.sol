// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "contracts/ProductIdentification.sol";
import "contracts/SampleToken.sol";

contract Auction {
    address payable internal auction_owner;
    uint256 public auction_start;
    uint256 public auction_end;
    uint256 public highestBid;
    address public highestBidder;

    enum auction_state {
        CANCELLED,
        STARTED
    }

    struct car {
        string Brand;
        string Rnumber;
    }

    car public Mycar;
    address[] bidders;

    mapping(address => uint256) public bids;

    auction_state public STATE;

    modifier an_ongoing_auction() {
        require(
            block.timestamp <= auction_end && STATE == auction_state.STARTED
        );
        _;
    }

    modifier only_owner() {
        require(msg.sender == auction_owner);
        _;
    }

    function bid() public payable virtual returns (bool) {}

    function bid2() public virtual returns (bool) {}

    function withdraw() public virtual returns (bool) {}

    function cancel_auction() external virtual returns (bool) {}

    event BidEvent(address indexed highestBidder, uint256 highestBid);
    event WithdrawalEvent(address withdrawer, uint256 amount);
    event CanceledEvent(string message, uint256 time);
}

contract MyAuction is Auction {
    ProductIdentification public productIdentification;
    SampleToken public sampleToken;

    constructor(
        uint256 _biddingTime,
        address payable _owner,
        string memory _brand,
        string memory _Rnumber,
        address payable _productIdentificationAddress,
        address _sampleTokenAddress
    ) {
        productIdentification = ProductIdentification(
            _productIdentificationAddress
        );
        require(
            productIdentification.isProductRegisteredByName(_brand),
            "The car's brand is not registered!"
        );

        sampleToken = SampleToken(_sampleTokenAddress);
        auction_owner = _owner;
        auction_start = block.timestamp;
        auction_end = auction_start + _biddingTime * 1 hours;
        STATE = auction_state.STARTED;
        Mycar.Brand = _brand;
        Mycar.Rnumber = _Rnumber;
    }

    function get_owner() public view returns (address) {
        return auction_owner;
    }

    fallback() external payable {}

    receive() external payable {}

    function bid2(uint256 _value) public an_ongoing_auction returns (bool) {
        require(_value > highestBid, "You can't bid, Make a higher Bid");
        require(bids[msg.sender] == 0, "You already made a bid");

        highestBidder = msg.sender;
        highestBid = _value;
        bidders.push(msg.sender);
        bids[msg.sender] = highestBid;

        require(
            sampleToken.transferFrom(msg.sender, address(this), _value),
            "There was a problem when trying to transfer tokens"
        );

        emit BidEvent(highestBidder, highestBid);

        return true;
    }

    function bid() public payable override an_ongoing_auction returns (bool) {
        require(
            bids[msg.sender] + msg.value > highestBid,
            "You can't bid, Make a higher Bid"
        );
        highestBidder = msg.sender;
        highestBid = bids[msg.sender] + msg.value;
        bidders.push(msg.sender);
        bids[msg.sender] = highestBid;
        emit BidEvent(highestBidder, highestBid);

        return true;
    }

    function cancel_auction()
        external
        override
        only_owner
        an_ongoing_auction
        returns (bool)
    {
        STATE = auction_state.CANCELLED;
        emit CanceledEvent("Auction Cancelled", block.timestamp);
        return true;
    }

    function withdraw() public override returns (bool) {
        require(
            block.timestamp > auction_end || STATE == auction_state.CANCELLED,
            "You can't withdraw, the auction is still open"
        );
        uint256 amount;

        amount = bids[msg.sender];
        bids[msg.sender] = 0;

        // payable(msg.sender).transfer(amount);
        require(
            sampleToken.transfer(msg.sender, amount),
            "There was a problem when trying to withdraw founds"
        );

        emit WithdrawalEvent(msg.sender, amount);
        return true;
    }

    function destruct_auction() external only_owner returns (bool) {
        require(
            block.timestamp > auction_end || STATE == auction_state.CANCELLED,
            "You can't destruct the contract,The auction is still open"
        );
        for (uint256 i = 0; i < bidders.length; i++) {
            assert(bids[bidders[i]] == 0);
        }

        selfdestruct(auction_owner);
        return true;
    }
}

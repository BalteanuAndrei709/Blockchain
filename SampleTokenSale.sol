// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "contracts/SampleToken.sol";

contract SampleTokenSale {
    SampleToken public tokenContract;
    uint256 public tokenPrice;
    address owner;

    uint256 public tokensSold;

    event Sell(address indexed _buyer, uint256 indexed _amount);

    constructor(SampleToken _tokenContract, uint256 _tokenPrice) {
        owner = msg.sender;
        tokenContract = _tokenContract;
        tokenPrice = _tokenPrice;
    }

    modifier isOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    function changeTokenPrice(uint256 _newPrice) public isOwner {
        require(_newPrice >= 0);
        tokenPrice = _newPrice;
    }

    function buyTokens(uint256 _numberOfTokens) public payable {
        require(
            msg.value >= _numberOfTokens * tokenPrice,
            "Not enough money provided!"
        );
        require(tokenContract.balanceOf(address(this)) >= _numberOfTokens);
        require(
            tokenContract.allowance(owner, address(this)) >= _numberOfTokens,
            "Sale contract is not allowed to sell this amount of tokens!"
        );
        
        tokensSold += _numberOfTokens;
        bool success = tokenContract.transferFrom(
            owner,
            msg.sender,
            _numberOfTokens
        );

        require(success);

        if (msg.value > _numberOfTokens * tokenPrice) {
            payable(msg.sender).transfer(
                msg.value - (_numberOfTokens * tokenPrice)
            );
        }

        emit Sell(msg.sender, _numberOfTokens);
    }

    function endSale() public isOwner {
        require(
            tokenContract.transfer(
                owner,
                tokenContract.balanceOf(address(this))
            )
        );
        payable(msg.sender).transfer(address(this).balance);
    }

    event receivePayment(address, uint256);
    event fallbackCalled(string);

    receive() external payable {
        emit receivePayment(msg.sender, msg.value);
    }

    fallback() external payable {
        emit fallbackCalled("Fallback function called!");
    }
}

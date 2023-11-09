// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "contracts/ProductIdentification.sol";
import "contracts/ProductDeposit.sol";

contract ProductStore {
    address public owner;
    ProductIdentification productIdentificationInstance;
    ProductDeposit productDepositInstance;

    uint256 internal transactionIdCounter;

    struct Product {
        uint256 pricePerUnit;
        uint256 quantity;
    }

    struct Transaction {
        address buyer;
        uint256 productId;
        uint256 amount;
        uint256 price;
    }

    mapping(uint256 => Product) public myStore; //idProdus => product
    mapping(uint256 => Transaction) public registeredTransactions;

    constructor() {
        owner = msg.sender;
        transactionIdCounter = 0;
    }

    modifier isOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    event productIdentificationContractRegistered(string);
    event productDepositContractRegistered(string);

    function setProductIdentificationContractAddress(address payable _address)
        external
        isOwner
    {
        productIdentificationInstance = ProductIdentification(_address);
        emit productIdentificationContractRegistered(
            "ProductIdentification contract registered!"
        );
    }

    function setProductDepositContractAddress(address payable _address)
        external
        isOwner
    {
        productDepositInstance = ProductDeposit(_address);
        emit productDepositContractRegistered(
            "ProductDeposit contract registered!"
        );
    }

    event receivePayment(address, uint256);
    event fallbackCalled(string);

    receive() external payable {
        emit receivePayment(msg.sender, msg.value);
    }

    fallback() external payable {
        emit fallbackCalled("Fallback called!");
    }

    event productAdded(
        address indexed byWho,
        uint256 productId,
        uint256 howMuch
    );

    function addProductIntoStore(uint256 productId, uint256 quantity) external {
        productDepositInstance.retrieveProduct(productId, quantity, msg.sender);

        //add product to store
        myStore[productId].quantity += quantity;
        emit productAdded((msg.sender), productId, quantity);
    }

    function setPricePerUnit(uint256 productId, uint256 price) external {
        require(
            myStore[productId].quantity == 0,
            "This product does not exists!"
        );
        myStore[productId].pricePerUnit = price;
    }

    function checkAvailabilityAndAuthenticity(uint256 productId)
        external
        view
        returns (bool)
    {
        if (myStore[productId].quantity == 0) {
            return false;
        }

        address producerOfProduct = productIdentificationInstance
            .isProductRegistered(productId)
            .producer;

        if (
            !productIdentificationInstance.isProducerRegistered(
                producerOfProduct
            )
        ) {
            return false;
        }

        return true;
    }

    event productSold(
        address indexed byWho,
        uint256 indexed productId,
        uint256 amount,
        uint256 howMuch
    );

    function buyProduct(uint256 productId, uint256 units) external payable {
        require(
            myStore[productId].quantity - units >= 0,
            "This product is out of availability!"
        );
        require(
            msg.value >= myStore[productId].pricePerUnit * units,
            "Not enough money provided!"
        );

        uint256 price = msg.value;
        if (msg.value > myStore[productId].pricePerUnit * units) {
            price = myStore[productId].pricePerUnit * units;
        }

        myStore[productId].quantity = myStore[productId].quantity - units;

        registeredTransactions[transactionIdCounter].buyer = msg.sender;
        registeredTransactions[transactionIdCounter].productId = productId;
        registeredTransactions[transactionIdCounter].amount = units;
        registeredTransactions[transactionIdCounter].price = price;

        address producerOfProduct = productIdentificationInstance
            .isProductRegistered(productId)
            .producer;

        payable(producerOfProduct).transfer(
            (units * myStore[productId].pricePerUnit) / 2
        );

        if (msg.value > myStore[productId].pricePerUnit * units) {
            payable(msg.sender).transfer(
                msg.value - (units * myStore[productId].pricePerUnit)
            );
        }

        emit productSold(msg.sender, productId, units, msg.value);
    }
}

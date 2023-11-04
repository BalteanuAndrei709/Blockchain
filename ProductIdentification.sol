// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// 1️⃣ Create a Twitter Contract 
// 2️⃣ Create a mapping between user and tweet 
// 3️⃣ Add function to create a tweet and save it in mapping
// 4️⃣ Create a function to get Tweet 
// 5️⃣ Add array of tweets 

contract ProductIdentification 
{
    address public owner;

    uint256 public registrationTax;
    uint256 internal productIdCounter;

    struct Producer {
        bool isRegistered;
    }

    struct Product {
        address producer;
        string name;
        uint256 volume;
    }

    mapping(address => Producer) public registeredProducers;
    mapping(uint256 => Product) public registeredProducts;
    

    event registrationTaxChanged(uint256 newTax);
    event ProducerRegistered(address producer);
    event ProductRegistered(address producer, string productName, uint256 volume);

    constructor()
    {
        owner = msg.sender;
        productIdCounter = 0;
    }

    modifier isOwner()
    {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    modifier isRegisteredProducer()
    {
        require(registeredProducers[msg.sender].isRegistered, "Only a registered producer can call this function.");
        _;
    }

    function changeRegistrationTax(uint256 newRegistrationTax) public isOwner
    {
        registrationTax = newRegistrationTax;
        emit registrationTaxChanged(registrationTax);
    }

    function registerAsProducer() public payable 
    {
        require(msg.value == registrationTax, "Registration tax is not correct.");
        require(!registeredProducers[msg.sender].isRegistered, "Producer is already registered.");
        registeredProducers[msg.sender].isRegistered = true;
        emit ProducerRegistered(msg.sender);
    }

    function registerProduct(string memory productName, uint256 volume) public isRegisteredProducer
    {
        productIdCounter++;
        registeredProducts[productIdCounter] =  Product(msg.sender, productName, volume);
        
        emit ProductRegistered(msg.sender, productName, volume);
    }

    function isProducerRegistered(address producerAddress) public view returns (bool)
    {
        return registeredProducers[producerAddress].isRegistered;
    }

    function isProductRegistered(uint256 productId) public view returns (Product memory) 
    {
        require(registeredProducts[productId].producer != address(0), "Product is not registered.");
        return registeredProducts[productId];
    }
}
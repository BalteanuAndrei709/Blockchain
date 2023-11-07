// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Balteanu Andrei
contract ProductIdentification {
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
    event ProductRegistered(
        address producer,
        string productName,
        uint256 volume
    );

    constructor() {
        owner = msg.sender;
        productIdCounter = 0;
    }

    modifier isOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    modifier isRegisteredProducer() {
        require(
            registeredProducers[msg.sender].isRegistered,
            "Only a registered producer can call this function."
        );
        _;
    }

    function changeRegistrationTax(uint256 newRegistrationTax) public isOwner {
        registrationTax = newRegistrationTax;
        emit registrationTaxChanged(registrationTax);
    }

    function registerAsProducer() public payable {
        require(
            msg.value == registrationTax,
            "Registration tax is not correct."
        );
        require(
            !registeredProducers[msg.sender].isRegistered,
            "Producer is already registered."
        );
        registeredProducers[msg.sender].isRegistered = true;
        emit ProducerRegistered(msg.sender);
    }

    function registerProduct(string memory productName, uint256 volume)
        public
        isRegisteredProducer
    {
        productIdCounter++;
        registeredProducts[productIdCounter] = Product(
            msg.sender,
            productName,
            volume
        );

        emit ProductRegistered(msg.sender, productName, volume);
    }

    function isProducerRegistered(address producerAddress)
        public
        view
        returns (bool)
    {
        return registeredProducers[producerAddress].isRegistered;
    }

    function isProductRegistered(uint256 productId)
        public
        view
        returns (Product memory)
    {
        require(
            registeredProducts[productId].producer != address(0),
            "Product is not registered."
        );
        return registeredProducts[productId];
    }

    event receivePayment(address, uint256);
    event fallbackCalled(string);

    receive() external payable {
        emit receivePayment(msg.sender, msg.value);
    }

    fallback() external {
        emit fallbackCalled("Fallback called!");
    }
}

// Filip Tudor
contract ProductDeposit {
    address public owner;
    address payable public productIdentificationContract;

    uint256 public taxPerVolumeUnit;
    uint256 public maxDepositVolume;
    uint256 internal currentDepositVolume;
    uint256 internal withdrawsIdCounter;

    struct Product {
        address producer;
        uint256 id;
        uint256 volume;
    }

    struct ProductStoreDetails {
        address productStore;
        address owner;
    }

    struct WithdrawDetails {
        address who;
        uint256 productId;
        uint256 amount;
    }

    mapping(uint256 => Product) public registeredProducts;
    mapping(address => ProductStoreDetails) public registeredProductStores;
    mapping(uint256 => WithdrawDetails) public registeredProductsWithdraws;

    event newTaxPerVolumeUnitRegistered(uint256 newTaxPerVolumeUnit);
    event newMaximumDepositVolumeRegistered(uint256 newMaxDepositVolume);
    event productDeposited(
        address indexed whom,
        uint256 productId,
        uint256 amount
    );
    event productStoreRegistered(address indexed owner, address productStoreId);
    event productWithdraw(
        address indexed who,
        uint256 productId,
        uint256 amount
    );

    constructor(address payable productIdentificationAddress) {
        owner = msg.sender;
        productIdentificationContract = productIdentificationAddress;
        taxPerVolumeUnit = 0;
        maxDepositVolume = 0;
        currentDepositVolume = 0;
        withdrawsIdCounter = 0;
    }

    modifier isOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    function increaseCurrentDepositVolume(uint256 amount) internal {
        require(
            currentDepositVolume + amount <= maxDepositVolume,
            "To much volume added into deposit!"
        );
        currentDepositVolume = currentDepositVolume + amount;
    }

    function decreaseCurrentDepositVolume(uint256 amount) internal {
        require(
            currentDepositVolume - amount >= 0,
            "Current deposit volume can not be negative!"
        );
        currentDepositVolume = currentDepositVolume - amount;
    }

    function setTaxPerVolumeUnit(uint256 value) public isOwner {
        taxPerVolumeUnit = value;
        emit newTaxPerVolumeUnitRegistered(value);
    }

    function setMaximumDepositVolume(uint256 maxVolume) public isOwner {
        maxDepositVolume = maxVolume;
        emit newMaximumDepositVolumeRegistered(maxVolume);
    }

    function depositProduct(uint256 productId, uint256 quantity)
        external
        payable
    {
        require(
            ((maxDepositVolume - quantity) >= 0),
            "Not enough space in deposit"
        );
        require(
            (quantity * taxPerVolumeUnit) >= msg.value,
            "You should pay more money to deposit the product"
        );

        if (
            ProductIdentification(productIdentificationContract)
                .isProductRegistered(productId)
                .producer != msg.sender
        ) {
            revert(
                "Product is not register or producer does not own the product"
            );
        }

        registeredProducts[productId] = Product(
            msg.sender,
            productId,
            quantity
        );
        increaseCurrentDepositVolume(quantity);

        emit productDeposited(msg.sender, productId, quantity);
    }

    function registerProductStore(address _productStore) external {
        require(
            ProductIdentification(productIdentificationContract)
                .isProducerRegistered(msg.sender),
            "Producer should be registed first!"
        );
        require(
            registeredProductStores[_productStore].productStore == address(0),
            "This Product Store was already registered!"
        );

        registeredProductStores[_productStore] = ProductStoreDetails(
            _productStore,
            msg.sender
        );

        emit productStoreRegistered(msg.sender, _productStore);
    }

    function retrieveProduct(uint256 productId, uint256 amount) external {
        require(
            (registeredProducts[productId].producer == msg.sender) ||
                (registeredProductStores[msg.sender].productStore ==
                    msg.sender),
            "Not allowed to retrieve this product"
        );
        
        if (registeredProducts[productId].volume - amount < 0) {
            revert("Can not retrieve more than the actual amount!");
        }
        
        registeredProducts[productId].volume = registeredProducts[productId].volume - amount;
        registeredProductsWithdraws[withdrawsIdCounter] = WithdrawDetails(
            msg.sender,
            productId,
            amount
        );
        decreaseCurrentDepositVolume(amount);

        emit productWithdraw(msg.sender, productId, amount);
    }

    event receivePayment(address, uint256);
    event fallbackCalled(string);

    receive() external payable {
        emit receivePayment(msg.sender, msg.value);
    }

    fallback() external {
        emit fallbackCalled("Fallback called!");
    }
}

// Roman Stefan
contract ProductStore {
    address public owner;
    address payable public productIdentificationContract;
    address payable public productDepositContract;

    struct ProductInfo {
        address owner;
        uint256 productId;
        uint256 amount;
    }

    mapping(address => ProductInfo) public registeredProducersAndTheirProducts;

    constructor() {
        owner = msg.sender;
    }

    modifier isOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    event productIdentificationContractRegistered(string);
    event productDepositContractRegistered(string);

    function setProductIdentificationContractAddress(address payable _address) external isOwner {
        productIdentificationContract = _address;
        emit productIdentificationContractRegistered("ProductIdentification contract registered!");
    }

    function setProductDepositContractAddress(address payable _address) external isOwner {
        productDepositContract = _address;
        emit productDepositContractRegistered("ProductDeposit contract registered!");
    }

    event receivePayment(address, uint256);
    event fallbackCalled(string);

    receive() external payable {
        emit receivePayment(msg.sender, msg.value);
    }

    fallback() external {
        emit fallbackCalled("Fallback called!");
    }

    function addProductIntoStore(uint256 productId, uint256 quantity) external {
        
    }
}
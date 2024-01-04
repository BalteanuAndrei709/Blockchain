// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "contracts/ProductIdentification.sol";

contract ProductDeposit {
    address public owner;
    ProductIdentification productIdentificationInstance;

    uint256 public taxPerVolumeUnit;
    uint256 public maxDepositVolume;
    uint256 internal currentDepositVolume;
    uint256 internal withdrawsIdCounter;

    struct Product {
        address producer;
        uint256 volume;
    }

    struct WithdrawDetails {
        address who;
        uint256 productId;
        uint256 amount;
    }

    mapping(uint256 => Product) public registeredProducts;
    mapping(address => address) public registeredProductStores;
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
        productIdentificationInstance = ProductIdentification(
            productIdentificationAddress
        );
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
            currentDepositVolume + quantity <= maxDepositVolume,
            "Not enough space in deposit!"
        );
        require(
            msg.value >= quantity * taxPerVolumeUnit,
            "You should pay more money to deposit the product!"
        );

        if (
            productIdentificationInstance
                .isProductRegistered(productId)
                .producer != msg.sender
        ) {
            revert(
                "Product is not register or producer does not own the product!"
            );
        }

        registeredProducts[productId] = Product(msg.sender, quantity);
        increaseCurrentDepositVolume(quantity);

        if (msg.value > quantity * taxPerVolumeUnit) {
            payable(msg.sender).transfer(
                msg.value - (quantity * taxPerVolumeUnit)
            );
        }

        emit productDeposited(msg.sender, productId, quantity);
    }

    function registerProductStore(address _productStore) external {
        require(
            productIdentificationInstance.isProducerRegistered(msg.sender),
            "Producer should be registed first!"
        );
        require(
            registeredProductStores[msg.sender] == address(0),
            "Producer already registered a store!"
        );

        registeredProductStores[msg.sender] = _productStore;

        emit productStoreRegistered(msg.sender, _productStore);
    }

    function retrieveProduct(uint256 productId, uint256 amount, address productOwner)
        external
        returns (bool)
    {
        require(
            (registeredProducts[productId].producer == productOwner) ||
                (registeredProductStores[productOwner] != address(0)),
            "Not allowed to retrieve this product"
        );

        if (registeredProducts[productId].volume - amount < 0) {
            revert("Can not retrieve more than the actual amount!");
        }

        registeredProducts[productId].volume -= amount;

        registeredProductsWithdraws[withdrawsIdCounter] = WithdrawDetails(
            productOwner,
            productId,
            amount
        );
        withdrawsIdCounter = withdrawsIdCounter + 1;
        decreaseCurrentDepositVolume(amount);

        emit productWithdraw(productOwner, productId, amount);

        return true;
    }

    event receivePayment(address, uint256);
    event fallbackCalled(string);

    receive() external payable {
        emit receivePayment(msg.sender, msg.value);
    }

    fallback() external payable {
        emit fallbackCalled("Fallback called!");
    }
}

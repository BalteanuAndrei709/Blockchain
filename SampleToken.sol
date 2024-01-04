// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract SampleToken {
    string public tokenName = "Platypus Token";
    string public tokenSymbol = "PLT";

    uint256 public tokenTotalSupply;

    bool mutex;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    mapping(address => uint256) public tokenBalanceOf;
    mapping(address => mapping(address => uint256)) public tokenAllowance;

    constructor(uint256 _initialSupply) {
        tokenBalanceOf[msg.sender] = _initialSupply;
        tokenTotalSupply = _initialSupply;
        emit Transfer(address(0x0), msg.sender, tokenTotalSupply);
    }

    modifier noReentrancy() {
        require(!mutex);
        mutex = true;
        _;
        mutex = false;
    }

    function transfer(address _to, uint256 _value)
        public
        noReentrancy
        returns (bool success)
    {
        require(tokenBalanceOf[msg.sender] >= _value);

        emit Transfer(msg.sender, _to, _value);
        tokenBalanceOf[msg.sender] -= _value;
        tokenBalanceOf[_to] += _value;

        return true;
    }

    function approve(address _spender, uint256 _value)
        public
        noReentrancy
        returns (bool success)
    {
        emit Approval(msg.sender, _spender, _value);
        tokenAllowance[msg.sender][_spender] = _value;
        return true;
    }

    function allowance(address _owner, address _spender)
        public
        view
        returns (uint256 remaining)
    {
        return tokenAllowance[_owner][_spender];
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public noReentrancy returns (bool success) {
        require(_value <= tokenBalanceOf[_from]);
        require(_value <= tokenAllowance[_from][msg.sender]);

        emit Transfer(_from, _to, _value);
        tokenBalanceOf[_from] -= _value;
        tokenBalanceOf[_to] += _value;
        tokenAllowance[_from][msg.sender] -= _value;
        return true;
    }

    function name() public view returns (string memory) {
        return tokenName;
    }

    function symbol() public view returns (string memory) {
        return tokenSymbol;
    }

    function totalSupply() public view returns (uint256) {
        return tokenTotalSupply;
    }

    function balanceOf(address _owner)
        public
        view
        returns (uint256 balance)
    {
        require(tokenBalanceOf[_owner] != 0, "There is no user with that");
        return tokenBalanceOf[_owner];
    }
}

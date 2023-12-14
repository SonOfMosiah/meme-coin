// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract MemeCoin is ERC20 {

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals) ERC20(_name, _symbol, _decimals
    ){}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        uint256 newAllowance = allowance(msg.sender, spender) + addedValue;
        _approve(msg.sender, spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 newAllowance = allowance(msg.sender, spender) - subtractedValue;
        _approve(msg.sender, spender, newAllowance);
        return true;
    }
}

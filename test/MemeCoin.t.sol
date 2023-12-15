// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MemeCoin} from "src/MemeCoin.sol";

contract MemeCoinTest is Test {
    MemeCoin public memecoin;

    string public constant name = "MemeCoin";
    string public constant symbol = "MEME";

    bool public taxEnabled = true;
    uint256 public tax = 100;
    uint256 public minTax = 100;
    uint256 public maxTax = 1000;
    address public taxDestination = address(0xdead);

    function setUp() public {
       memecoin = new MemeCoin(name, symbol, taxEnabled, tax, minTax, maxTax, taxDestination, 1_000, 1_000_000_000 * 1 ether, msg.sender);
    }
}

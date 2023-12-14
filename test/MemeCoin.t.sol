// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MemeCoin} from "src/MemeCoin.sol";

contract MemeCoinTest is Test {
    MemeCoin public memecoin;

    string public constant name = "MemeCoin";
    string public constant symbol = "MEME";
    uint8 public constant decimals = 18;
    function setUp() public {
       memecoin = new MemeCoin(name, symbol, decimals);
    }
}

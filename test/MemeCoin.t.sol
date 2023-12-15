// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MemeCoin} from "src/MemeCoin.sol";

contract MemeCoinTest is Test {
    MemeCoin public memecoin;

    string public constant name = "MemeCoin";
    string public constant symbol = "MEME";

    bool public taxEnabled = true;
    uint256 public tax = 100;
    uint256 public minTax = 100;
    uint256 public maxTax = 1_000;
    address public taxDestination = address(0xdeadbeef);

    uint256 public constant initialSupply = 1_000_000_000;
    uint256 public constant maxHoldingPercent = 1_000;
    uint256 public constant PRECISION = 10_000;

    function setUp() public {
       memecoin = new MemeCoin(name, symbol, taxEnabled, tax, minTax, maxTax, taxDestination, maxHoldingPercent, initialSupply, msg.sender);
    }

    function testConstructor() public {
        assertEq(memecoin.name(), name);
        assertEq(memecoin.symbol(), symbol);
        assertEq(memecoin.taxEnabled(), taxEnabled);
        assertEq(memecoin.tax(), tax);
        assertEq(memecoin.minTax(), minTax);
        assertEq(memecoin.maxTax(), maxTax);
        assertEq(memecoin.taxDestination(), taxDestination);
        assertEq(memecoin.maxHoldingPerWallet(), initialSupply * 1 ether * maxHoldingPercent / PRECISION);
        assertEq(memecoin.totalSupply(), initialSupply * 1 ether);
        assertEq(memecoin.balanceOf(msg.sender), initialSupply * 1 ether);
    }

    function testUpdateTax() public {
        uint256 newTax = 200;
        vm.prank(msg.sender);
        memecoin.updateTax(newTax);
        assertEq(memecoin.tax(), newTax);
    }

    function testUpdateTaxLowerThanMin() public {
        vm.startPrank(msg.sender);
        uint256 newTax = 99;
        vm.expectRevert();
        memecoin.updateTax(newTax);
        vm.stopPrank();
    }

    function testUpdateTaxHigherThanMax() public {
        uint256 newTax = 1001;
        vm.startPrank(msg.sender);
        vm.expectRevert();
        memecoin.updateTax(newTax);
        vm.stopPrank();
    }

    function updateTaxNotOwner() public {
        uint256 newTax = 200;
        vm.expectRevert();
        memecoin.updateTax(newTax);
    }

    function testUpdateTaxDestination() public {
        vm.startPrank(msg.sender);
        address newTaxDestination = address(0xbeef);
        memecoin.updateTaxDestination(newTaxDestination);
        assertEq(memecoin.taxDestination(), newTaxDestination);
        vm.stopPrank();
    }

    function testUpdateTaxDestinationZeroAddress() public {
        vm.startPrank(msg.sender);
        address newTaxDestination = address(0x0);
        vm.expectRevert();
        memecoin.updateTaxDestination(newTaxDestination);
        vm.stopPrank();
    }

    function testUpdateTaxDestinationNotOwner() public {
        address newTaxDestination = address(0xbeef);
        vm.expectRevert();
        memecoin.updateTaxDestination(newTaxDestination);
    }

    function disableTax() public {
        vm.startPrank(msg.sender);
        memecoin.disableTax();
        assertEq(memecoin.taxEnabled(), false);
        vm.stopPrank();
    }

    function disableTaxNotOwner() public {
        vm.expectRevert();
        memecoin.disableTax();
    }

    function enableTax() public {
        vm.startPrank(msg.sender);
        memecoin.enableTax();
        assertEq(memecoin.taxEnabled(), true);
        vm.stopPrank();
    }

    function enableTaxNotOwner() public {
        vm.expectRevert();
        memecoin.enableTax();
    }

    function testSetMaxHoldingExempt() public {
        address exemptAddress = address(0xbeef);
        vm.startPrank(msg.sender);
        memecoin.setMaxHoldingExempt(exemptAddress, true);
        assertEq(memecoin.isMaxHoldingExempt(exemptAddress), true);
        vm.stopPrank();
    }

    function testSetMaxHoldingExemptAndTransfer() public {
        address exemptAddress = address(0xbeef);
        vm.startPrank(msg.sender);
        memecoin.setMaxHoldingExempt(exemptAddress, true);
        assertEq(memecoin.isMaxHoldingExempt(exemptAddress), true);
        memecoin.transfer(exemptAddress, initialSupply * 1 ether);
        assertEq(memecoin.balanceOf(exemptAddress), initialSupply * 1 ether);
        vm.stopPrank();
    }

    function testTransferTaxFromExempt() public {
        address to = address(0xbeef);
        vm.startPrank(msg.sender);
        memecoin.transfer(to, 1_000_000 ether);
        assertEq(memecoin.balanceOf(to), 1_000_000 ether);
        vm.stopPrank();
    }

    function testTransferTaxToExempt() public {
        address to = address(0xbeef);

        vm.startPrank(msg.sender);
        memecoin.transfer(to, 1_000_000 ether);
        assertEq(memecoin.balanceOf(to), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(to);
        memecoin.transfer(msg.sender, 1_000_000 ether);
        assertEq(memecoin.balanceOf(msg.sender), initialSupply * 1 ether);
        vm.stopPrank();
    }

    function testTransferTax() public {
        address from = address(0xbeef);
        address to = address(0xdead);
        uint256 transferAmount = 1_000_000 ether;
        vm.startPrank(msg.sender);
        memecoin.transfer(from, transferAmount);
        assertEq(memecoin.balanceOf(from), transferAmount);
        memecoin.enableTax();
        vm.stopPrank();

        vm.startPrank(from);
        console.log('taxEnabled:', memecoin.taxEnabled());
        memecoin.transfer(to, transferAmount);
        uint256 expectedBalance = transferAmount - transferAmount * tax / PRECISION;
        console.log("expectedBalance", expectedBalance);
        console.log('taxDestination', memecoin.taxDestination());
        console.log("balanceOf", memecoin.balanceOf(to));
        console.log("balanceOf", memecoin.balanceOf(from));
        assertEq(memecoin.balanceOf(to), transferAmount - transferAmount * tax / PRECISION);
        vm.stopPrank();
    }
}

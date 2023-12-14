// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MemeCoin is ERC20, ReentrancyGuard, Ownable, Pausable {

    /// @notice Event emitted when a user is blocked
    /// @param user The address of the blocked user
    error Blocked(address user);

    /// @notice Event emitted when a user has insufficient balance
    error InsufficientBalance();

    error ZeroAddress();
    error InvalidTaxRange();

    event TaxEnabled();
    event TaxDisabled();
    event TaxUpdated(uint256 newTax);
    event TaxDestinationUpdated(address newDestination);
    event AddressBlocked(address user);
    event AddressUnblocked(address user);

    /// @notice Mapping of blocked addresses
    mapping (address user => bool isBlocked) public isBlocked;
    /// @notice Mapping of addresses that are not taxed when sending
    mapping (address user => bool notTaxedFrom) public notTaxedFrom;
    /// @notice Mapping of addresses that are not taxed when receiving
    mapping (address user => bool notTaxedTo) public notTaxedTo;
    /// @notice Mapping of addresses that are always taxed when sending
    mapping (address user => bool alwaysTaxedFrom) public alwaysTaxedFrom;
    /// @notice Mapping of addresses that are always taxed when receiving
    mapping (address user => bool alwaysTaxedTo) public alwaysTaxedTo;

    bool public taxEnabled;
    address public taxDestination;
    uint256 public tax; // e.g. 100 = 1%
    uint256 public immutable minTax; // e.g. 100 = 1%
    uint256 public immutable maxTax; // e.g. 1_000 = 10%

    uint256 public constant TAX_PRECISION = 10_000;

    constructor(
        string memory _name,
        string memory _symbol,
        bool _taxEnabled,
        uint256 _tax,
        uint256 _minTax,
        uint256 _maxTax,
        address _taxDestination,
        address _owner
    )
    ERC20(_name, _symbol)
    Ownable(_owner)
    {
        if (_minTax > _maxTax || _tax > _maxTax || _tax < _minTax || _minTax > TAX_PRECISION) {
            revert InvalidTaxRange();
        }
        notTaxedFrom[_owner] = true;
        notTaxedTo[_owner] = true;
        taxEnabled = _taxEnabled;
        taxDestination = _taxDestination;
        tax = _tax;
        minTax = _minTax;
        maxTax = _maxTax;
    }

    function enableTax() public onlyOwner {
        taxEnabled = true;
        emit TaxEnabled();
    }

    function disableTax() public onlyOwner {
        taxEnabled = false;
        emit TaxDisabled();
    }

    function updateTax(uint256 newTax) public onlyOwner {
        tax = newTax;
        emit TaxUpdated(newTax);
    }

    function updateTaxDestination(address newDestination) public onlyOwner {
        taxDestination = newDestination;
        emit TaxDestinationUpdated(newDestination);
    }

    /// @notice Pause the contract
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice add an address to the blocklist
    /// @dev "block" is a reserved symbol in Solidity, so we use "blockUser" instead
    /// @param _address The address to add to the blocklist
    function blockUser(address _address) external onlyOwner {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        isBlocked[_address] = true;
        emit AddressBlocked(_address);
    }

    /// @notice remove an address from the blocklist
    /// @param _address The address to remove from the blocklist
    function unblock(address _address) external onlyOwner {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        isBlocked[_address] = false;
        emit AddressUnblocked(_address);
    }

    function setNotTaxedFrom(address _address, bool _notTaxed) external onlyOwner {
        notTaxedFrom[_address] = _notTaxed;
    }

    function setNotTaxedTo(address _address, bool _notTaxed) external onlyOwner {
        notTaxedTo[_address] = _notTaxed;
    }

    function setAlwaysTaxedFrom(address _address, bool _alwaysTaxed) external onlyOwner {
        alwaysTaxedFrom[_address] = _alwaysTaxed;
    }

    function setAlwaysTaxedTo(address _address, bool _alwaysTaxed) external onlyOwner {
        alwaysTaxedTo[_address] = _alwaysTaxed;
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        if (isBlocked[from]) revert Blocked(from);
        if (isBlocked[to]) revert Blocked(to);

        // check if the sender or receiver is not taxed
        if((!taxEnabled || notTaxedFrom[from] || notTaxedTo[to])
            && !alwaysTaxedFrom[from] && !alwaysTaxedTo[to]) {
            super._update(from, to, amount);
        } else {
            if (amount > balanceOf(from)) revert InsufficientBalance();
            super._update(from, taxDestination, amount * tax / TAX_PRECISION);
            super._update(from, to, amount * (TAX_PRECISION - tax) / TAX_PRECISION);
        }
    }
}

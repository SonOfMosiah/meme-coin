// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MemeCoin is ERC20, ReentrancyGuard, Ownable {

    /// @notice Event emitted when a user is blocked
    /// @param user The address of the blocked user
    error Blocked(address user);

    /// @notice Thrown when a user has insufficient balance
    error InsufficientBalance();

    /// @notice Thrown when a zero address is used
    error ZeroAddress();
    /// @notice Thrown when the new tax is out of range
    error InvalidTaxRange();
    /// @notice Thrown when the balance of the receiving wallet will exceed the max holding limit
    error MaxHoldingReached();

    /// @notice Emitted when tax is enabled
    event TaxEnabled();
    /// @notice Emitted when tax is disabled
    event TaxDisabled();
    /// @notice Emitted when the tax amount is updated
    /// @param newTax The new tax
    event TaxUpdated(uint256 newTax);
    /// @notice Emitted when the tax destination is updated
    /// @param newDestination the new address to receive the tax
    event TaxDestinationUpdated(address newDestination);
    /// @notice Emitted when an address is blocked
    /// @param user The address of the blocked account
    event AddressBlocked(address user);
    /// @notice Emitted when a user is unblocked
    /// @param user The address of the unblocked account
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
    /// @notice Mapping of addresses that are exempt from the max holding limit
    mapping (address user => bool isExempt) public isMaxHoldingExempt;

    /// @notice Whether tax is enabled
    bool public taxEnabled;
    /// @notice The address to receive the taxes
    address public taxDestination;
    /// @notice The tax amount (e.g. 100 = 1%)
    uint256 public tax;
    /// @notice The minimum tax (e.g. 100 = 1%)
    uint256 public immutable minTax;
    /// @notice the maximum tax (e.g. 100 = 1%)
    uint256 public immutable maxTax;

    /// @notice The max amount a wallet can hold
    uint256 public immutable maxHoldingPerWallet;

    uint256 private constant TAX_PRECISION = 10_000;
    uint256 private constant HOLDING_PRECISION = 10_000;

    /// @param _name The name of the token
    /// @param _symbol The symbol of the token
    /// @param _taxEnabled Whether the tax is enabled
    /// @param _tax The tax amount (e.g. 100 = 1%)
    /// @param _minTax the minimum tax (e.g. 100 = 1%)
    /// @param _maxTax the maximum tax (e.g. 100 = 1%)
    /// @param _taxDestination The address to receive taxes
    /// @param maxHoldingPercent The percentage of the totalSupply that a wallet is allowed to hold (e.g. 100 = 1%)
    /// @param initialSupply The supply to be minted upon contract creation (will be multiplied by 10 ** 18)
    /// @param _owner The address of the contract owner
    constructor(
        string memory _name,
        string memory _symbol,
        bool _taxEnabled,
        uint256 _tax,
        uint256 _minTax,
        uint256 _maxTax,
        address _taxDestination,
        uint256 maxHoldingPercent,
        uint256 initialSupply,
        address _owner
    )
    ERC20(_name, _symbol)
    Ownable(_owner)
    {
        if (_minTax > _maxTax || _tax > _maxTax || _tax < _minTax || _minTax > TAX_PRECISION) {
            revert InvalidTaxRange();
        }
        taxEnabled = _taxEnabled;
        tax = _tax;
        minTax = _minTax;
        maxTax = _maxTax;
        _updateTaxDestination(_taxDestination);
        maxHoldingPerWallet = initialSupply * 1 ether * maxHoldingPercent / HOLDING_PRECISION;
        notTaxedFrom[_owner] = true;
        notTaxedTo[_owner] = true;
        isMaxHoldingExempt[_owner] = true;
        _mint(_owner, initialSupply * 1 ether);
    }

    function enableTax() external onlyOwner {
        taxEnabled = true;
        emit TaxEnabled();
    }

    function disableTax() external onlyOwner {
        taxEnabled = false;
        emit TaxDisabled();
    }

    function updateTax(uint256 newTax) external onlyOwner {
        if (newTax < minTax || newTax > maxTax) {
            revert InvalidTaxRange();
        }
        tax = newTax;
        emit TaxUpdated(newTax);
    }

    /// @notice Updates the tax destination to `newAddress`
    /// @param newDestination The new address to receive taxes
    function updateTaxDestination(address newDestination) external onlyOwner {
        _updateTaxDestination(newDestination);
    }

    /// @notice Set `exemptAddress` as exempt from the max holding limit
    /// @param exemptAddress The exempt address
    /// @param isExempt Whether the address is exempt from the max holding limit
    function setMaxHoldingExempt(address exemptAddress, bool isExempt) external onlyOwner {
        isMaxHoldingExempt[exemptAddress] = isExempt;
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

    /// @notice Set an address that is not taxed when sending
    /// @param _address User address
    /// @param _notTaxed Whether the user should be tax exempt when sending
    function setNotTaxedFrom(address _address, bool _notTaxed) external onlyOwner {
        notTaxedFrom[_address] = _notTaxed;
    }

    /// @notice Set an address that is not taxed when receiving
    /// @param _address User address
    /// @param _notTaxed Whether the address should be tax exempt when receiving
    function setNotTaxedTo(address _address, bool _notTaxed) external onlyOwner {
        notTaxedTo[_address] = _notTaxed;
    }

    /// @notice Set an address that is always taxed when sending
    /// @param _address User address
    /// @param _alwaysTaxed Whether the address should always be taxed when sending
    function setAlwaysTaxedFrom(address _address, bool _alwaysTaxed) external onlyOwner {
        alwaysTaxedFrom[_address] = _alwaysTaxed;
    }

    /// @notice Set an address that is always taxed when receiving
    /// @param _address User address
    /// @param _alwaysTaxed Whether the address should always be taxed when receiving
    function setAlwaysTaxedTo(address _address, bool _alwaysTaxed) external onlyOwner {
        alwaysTaxedTo[_address] = _alwaysTaxed;
    }

    function _updateTaxDestination(address newDestination) internal {
        if (newDestination == address(0)) revert ZeroAddress();
        taxDestination = newDestination;
        emit TaxDestinationUpdated(newDestination);
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        if (isBlocked[from]) revert Blocked(from);
        if (isBlocked[to]) revert Blocked(to);

        // check if the sender or receiver is not taxed
        if((!taxEnabled || notTaxedFrom[from] || notTaxedTo[to])
            && !alwaysTaxedFrom[from] && !alwaysTaxedTo[to]) {
            if (!isMaxHoldingExempt[to] && balanceOf(to) + amount > maxHoldingPerWallet) revert MaxHoldingReached();
            super._update(from, to, amount);
        } else {
            if (amount > balanceOf(from)) revert InsufficientBalance();
            if (!isMaxHoldingExempt[to] && balanceOf(to) + (amount * (TAX_PRECISION - tax) / TAX_PRECISION) > maxHoldingPerWallet) revert MaxHoldingReached();
            super._update(from, taxDestination, amount * tax / TAX_PRECISION);
            super._update(from, to, amount * (TAX_PRECISION - tax) / TAX_PRECISION);
        }
    }
}

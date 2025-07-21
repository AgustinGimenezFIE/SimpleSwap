// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MyToken
/// @notice Basic ERC20 token with owner-only mint functionality
/// @dev Inherits from OpenZeppelin's ERC20
contract MyToken is ERC20 {
    /// @notice Address that owns the contract and can mint tokens
    address public owner;

    /// @notice Restricts function to only the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    /// @notice Constructor sets the token name, symbol, and assigns owner
    /// @param sym Token symbol (e.g., "TKA")
    /// @param name Token name (e.g., "Token A")
    constructor(string memory sym, string memory name) ERC20(name, sym) {
        owner = msg.sender;
    }

    /// @notice Mints `amount` tokens to address `to`
    /// @dev Can only be called by the owner
    /// @param to Address to receive the minted tokens
    /// @param amount Amount of tokens to mint (in smallest unit)
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

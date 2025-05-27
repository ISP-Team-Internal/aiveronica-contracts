// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20, Ownable {
    constructor(address initialOwner, string memory tokenName, string memory tokenNameShort) ERC20(tokenName, tokenNameShort) Ownable(initialOwner) {
        _mint(initialOwner, 0 * 10**18); // Mint 1M tokens to the initial owner
    }

    // Function to mint additional tokens (for testing purposes)
    function mint(address to, uint256 amount) public  {
        _mint(to, amount);
    }
}
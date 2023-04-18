// SPDX-License-Identifier: GPL-3.0
pragma solidity > 0.8.0;
//Implementacion of the ERC20 Implementation
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stoken is ERC20, Ownable {
    
    constructor(uint256 tokens) ERC20("SmartTokenX", "STX") Ownable() {
        _mint(msg.sender, tokens);
    }

    function mint(address to, uint256 tokens) public onlyOwner {
        _mint(to, tokens);
    }

    function burn(address from, uint256 tokens) public onlyOwner {
        _burn(from, tokens);
    }
}
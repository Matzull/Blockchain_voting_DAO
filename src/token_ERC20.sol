// SPDX-License-Identifier: GPL-3.0
pragma solidity > 0.8.0;
//Implementacion of the ERC20 Implementation
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stoken is ERC20, Ownable {
    
    constructor(uint256 tokenAmount) ERC20("SmartTokenX", "STX") Ownable() {
        _mint(msg.sender, tokenAmount * (10 ** uint256(decimals())));
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount * (10 ** uint256(decimals())));
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount * (10 ** uint256(decimals())));
    }
}
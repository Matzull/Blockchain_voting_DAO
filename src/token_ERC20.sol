// SPDX-License-Identifier: GPL-3.0
pragma solidity > 0.8.0;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.0/contracts/token/ERC20/ERC20.sol";

contract Toekn is ERC20 {
    constructor() ERC20("SmartTokenX", "STX") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}
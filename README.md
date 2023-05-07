# DAO and _on chain_  voting systems

This project aims to create a practical on-chain quadratic voting system for DAOs. The system is designed to facilitate the decision-making process of the DAO by allowing token holders to cast their votes in a weighted manner based on the number of tokens they hold. The implementation of the system is carried out through the use of a smart contract that utilizes the ERC20 token called SmartTokenX (**STX**). The voting system is intended to be transparent, secure, and efficient, providing a fair representation of the collective opinion of the token holders.

## Structure

* All the contracts are in the folder _contracts/_, they can be used as they are.
* In the directory _test/_ there is a test wrote using the hardhat framework. To test the project using this unit tests refer to the section testing of this document or the "Building and testing" section in the memory.
* The directory scripts contains the deployment script for the use in the hardhat framework.

## Testing

* Requirements:
  * Node.js > 16.0.0
  * Hardhat: Can be easily installed with: ```npm install --save-dev hardhat```
  * Hardhat toolbox: Installed with: ```npm i @nomicfoundation/hardhat-toolbox```
  
To compile:<br>
    ```npx hardhat compile```
<br>
<br>
To test:<br>
    ```npx hardhat test```

// SPDX-License-Identifier: GPL-3.0
pragma solidity > 0.8.0;

import "./IExecutableProposal.sol";

contract Proposal is IExecutableProposal {
    event executedProposal(uint proposalId, uint numVotes, uint numTokens);
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external payable
    {
        emit executedProposal(proposalId, numVotes, numTokens);
    }
}
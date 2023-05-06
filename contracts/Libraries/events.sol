// SPDX-License-Identifier: GPL-3.0
pragma solidity > 0.8.0;

library Events {
    event Print(uint proposalId, uint budget);
    event CanceledProposal(uint proposalId);
    event ProposalCreated(uint proposalId, uint budget);
    event ProposalCanceled(uint proposalId);
    event VoterCreated(address voterAddress);
    event VoterRemoved(address voterAddress);
    event VoteStaked(uint proposalId, address voterAddress, uint votes);
    event VoteWithdrawed(uint proposalId, address voterAddress, uint votes);
}
interface IExecutableProposal {
    function executeProposal(uint proposalId, uint numVotes,
    uint numTokens) external payable;
}
// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.8.0;

import "./token_ERC20.sol";
import "./IExecutableProposal.sol";
import "./Libraries/safeMath.sol";
import "./Libraries/events.sol";

/*In the creation of this contract you must provide the price in Wei of each token and the maximum number of tokens to be put up for
the maximum number of tokens to be offered for sale for voting. Among other things, the
Among other things, the builder must create the ERC20 type contract that manages the tokens. In
more details about the ERC20 standard code are provided in section 3.*/
contract quadraticVoting is Ownable {
    uint256 private tokenPrice = 300000; // 1 token = 300000 wei ≃ 5,5 eur
    uint256 private tokenAmount = 1000000;
    uint256 private totalBudget;

    uint8 private isVotingOpen; //0 = voting is closed | 1 = voting is open | 2 = voters can withdraw

    Stoken private token;
    struct t_proposal {
        string title;
        string description;
        uint256 budget;
        uint256 voteAmount;
        address creator;
        uint256 currentBudget;
        mapping(address => uint256) _voters;
        IExecutableProposal proposal;
        bool active; //This field is true if the proposal is still votable
    }

    uint256 numberOfProposals;
    mapping(uint256 => t_proposal) _proposals; //Maps a proposal to its id
    //The following arrays keep track of the corresponding proposal ids in the _proposals mapping
    uint256[] _SignalingProposals;
    uint256[] _ApprovedProposals; //Proposals in this array are also marked as (active => false)
    uint256[] _PendingProposals;

    uint256 _numberOfParticipants;
    mapping(address => uint) _participants; //addresses and 1 if they are participants

    modifier onlyParticipant() {
        require(_participants[msg.sender] != 0, "Not a participant");
        _;
    }

    modifier VotingOpen() {
        require(isVotingOpen == 1, "Voting is closed");
        _;
    }

    modifier onlyRefundSession() {
        require(isVotingOpen == 2, "Cannot refund now");
        _;
    }

    modifier votingOpenOrRefund() {
        require(isVotingOpen != 0, "Voting is closed");
        _;
    }

    //only the creator of the proposal with id proposalId can call this function
    modifier OnlyCreator(uint256 proposalId) {
        require(
            _proposals[proposalId].creator == msg.sender,
            "Voting is closed"
        );
        _;
    }

    modifier proposalActive(uint256 proposalId) {
        require(_proposals[proposalId].active, "Proposal must be open.");
        _;
    }

    modifier notSignalingProposal(uint256 proposalId) {
        require(
            _proposals[proposalId].budget != 0,
            "Must be a financial proposal"
        );
        _;
    }

    //This contract inherits from Ownable
    constructor() Ownable() {
        token = new Stoken(0); //It starts with 0 tokens
        numberOfProposals = 1; //We start in one to keep 0 as the error code
    }

    /*openVoting(): Opening of the voting period. It can only be executed by the user who
    created the contract. In the transaction that executes this function, the initial budget that will be available to finance proposals must be transferred.
    the initial budget that will be available to finance proposals. Remember that
    this total budget will be modified when proposals are approved: it will be increased by the contributions in tokens.
    with the contributions in tokens from the votes of the proposals that are approved and will be
    and will be decreased by the amount that is transferred to the proposals that are approved.*/

    function openVoting() public payable onlyOwner {
        totalBudget = msg.value;
        isVotingOpen = 1;
    }

    /*addParticipant(): Function used by participants to register for voting.
    Participants can register at any time, even before the voting period opens.
    the voting period opens. When registering, participants are required to transfer Ether
    to purchase tokens (at least one token) that they will use to cast their votes.
    This function must create and allocate the tokens that can be purchased with that amount.*/

    function addParticipant() public payable {
        require(
            msg.value >= tokenPrice,
            "Not enough Ether to purchase 1 token"
        );
        token.mint(msg.sender, (msg.value * (10 ** 18)) / tokenPrice);
        _participants[msg.sender] = 1;
        _numberOfParticipants++;
        emit Events.VoterCreated(msg.sender);
    }

    /*removeParticipant(): Function for a participant to remove himself/herself from the system.
    A participant who invokes this function will not be able to cast votes, create proposals or
    buy or sell tokens, unless it is re-added as a participant.*/

    function removeParticipant() public onlyParticipant {
        _participants[msg.sender] = 0;
        _numberOfParticipants--;
        emit Events.VoterRemoved(msg.sender);
    }

    /* addProposal(): Function that creates a proposal. Any participant can create proposals, but only when voting is open.
    proposals, but only when voting is open. It receives all the attributes of the
    proposal: title, description, budget needed to carry out the proposal (it can be zero if it is a proposal).
    (it can be zero if it is a signaling proposal) and the address of a contract that will implement the ExecutableProgram interface.
    the ExecutableProposal interface, which will be the recipient of the budgeted money if the proposal is approved.
    if the proposal is approved. It must return an identifier of the proposal
    created.*/

    function addProposal(
        string calldata _title,
        string calldata _description,
        uint256 _budget,
        address _proposalAddress
    ) public VotingOpen onlyParticipant returns (uint256) {
        // _proposals[numberOfProposals] = new t_proposal(title, description, budget, 0, msg.sender, 0, proposal : IExecutableProposal(proposalAddress), active : true);
        t_proposal storage p = _proposals[numberOfProposals];
        p.title = _title;
        p.description = _description;
        p.budget = _budget;
        p.voteAmount = 0;
        p.creator = msg.sender;
        p.currentBudget = 0;
        p.proposal = IExecutableProposal(_proposalAddress);
        p.active = true;
        emit Events.ProposalCreated(numberOfProposals, p.budget);
        if (_budget == 0) {
            //If budget is 0 it is a signaling proposal
            //We save the signaling proposal id into _SignalingProposals array
            _SignalingProposals.push(numberOfProposals);
        } else {
            //We save the proposal id into _PendingProposals array
            // _PendingProposals[_SignalingProposals.length] =  numberOfProposals;
            _PendingProposals.push(numberOfProposals);
        }
        return numberOfProposals++;
    }

    /*cancelProposal(): Cancels a proposal given its identifier. It can only be executed
    can only be executed if the vote is open. The only one who can perform this action is the creator of the proposal.
    creator of the proposal. Proposals that have already been approved cannot be cancelled. The tokens received so far to
    to vote on the proposal must be returned to their owners.*/

    function cancelProposal(uint256 proposalId) public OnlyCreator(proposalId) {
        uint256[] memory id = new uint256[](1);
        id[0] = proposalId;
        _proposals[proposalId].active = false;
        emit Events.ProposalCanceled(proposalId);
    }

    /*buyTokens(): buyTokens(): This function allows an already registered participant to buy more tokens to cast votes.*/

    function buyTokens() public payable onlyParticipant {
        token.mint(msg.sender, (msg.value * (10 ** 18)) / tokenPrice);
    }

    /*sellTokens(): Complementary operation to the previous one: allows a participant to return unspent tokens in votes and recover the money invested in them.*/

    function sellTokens(uint256 amount) public onlyParticipant {
        // tokens is actually ether here
        uint256 tokens = (amount / (10 ** 18)) * tokenPrice;
        require(
            token.balanceOf(msg.sender) >= tokens,
            "Not enough tokens to sell"
        );
        payable(msg.sender).transfer(tokens);
        // the amount burned is the amount
        token.burn(msg.sender, amount); //TODO seller wants to input number of tokens
    }

    /*getERC20(): Returns the address of the ERC20 contract used by the voting system to manage tokens. to manage tokens. In this way, participants can use it to operate with the tokens purchased (transfer them, exchange them, transfer the tokens, etc.). with the purchased tokens (transfer them, assign them, etc.).*/

    function getERC20() public view returns (address) {
        return address(token);
    }

    /* getPendingProposals(): Returns an array with the identifiers of all pending funding proposals. It can only be executed if the vote is open.*/

    function getPendingProposals()
        public
        view
        VotingOpen
        returns (uint256[] memory)
    {
        return _PendingProposals;
    }

    /*getApprovedProposals(): Returns an array with the identifiers of all approved funding proposals. proposals approved. It can only be executed if the vote is open.*/

    function getApprovedProposals()
        public
        view
        VotingOpen
        returns (uint256[] memory)
    {
        return _ApprovedProposals;
    }

    /*getSignalingProposals(): Returns an array with the identifiers of all the signaling proposals (those created with zero budget). signaling proposals (those created with zero budget). It can only be executed can only be executed if the vote is open.*/

    function getSignalingProposals()
        public
        view
        VotingOpen
        returns (uint256[] memory)
    {
        return _SignalingProposals;
    }

    /*getProposalInfo(): Returns the data associated with a proposal given its identifier.
    It can only be executed if the vote is open.*/

    function getProposalInfo(
        uint256 proposalId
    ) public view VotingOpen returns (string memory) {
        /*emit Events.ProposalInfo(proposalId,
            _proposals[proposalId].title,
            _proposals[proposalId].description,
            _proposals[proposalId].budget,
            _proposals[proposalId].voteAmount,
            _proposals[proposalId].creator,
            _proposals[proposalId].currentBudget,
            _proposals[proposalId].active);
            */
        return
            string.concat(
                "title: ",
                _proposals[proposalId].title,
                "\n",
                "description: ",
                _proposals[proposalId].description
            );
    }

    function getProposalInfo_budget(
        uint256 proposalId
    ) public view votingOpenOrRefund returns (uint256) {
        return _proposals[proposalId].budget;
    }

    function getProposalInfo_currentBudget(
        uint256 proposalId
    ) public view votingOpenOrRefund returns (uint256) {
        return _proposals[proposalId].currentBudget;
    }

    function getProposalInfo_voteAmount(
        uint256 proposalId
    ) public view votingOpenOrRefund returns (uint256) {
        return _proposals[proposalId].voteAmount;
    }

    function getProposalInfo_active(
        uint256 proposalId
    ) public view votingOpenOrRefund returns (bool) {
        return _proposals[proposalId].active;
    }

    /* stake(): receives a proposal identifier and the number of votes to be cast and casts the vote of the participant who invokes this function. It calculates the tokens needed to cast the votes to be cast and checks that the participant has assigned (with approve) the use of those tokens to the voting contract account. Remember that a participant can vote several times (and in different stake calls) for the same proposal with the same token. The code for this code is the same as the code for the stake.
    The code of this function must transfer the corresponding amount of tokens from the participant's account to the stake account. the participant's account to the account of this QuadraticVoting contract in order to be able to trade them. to trade with them. As this transfer is performed by this contract, the voter must have previously transferred with approve the tokens. previously transferred with approve the tokens corresponding to this contract (this transfer of tokens should not be programmed in the of tokens must not be programmed in QuadraticVoting: it must be carried out by the participant with the ERC20 contract before with the ERC20 contract before executing this function; the ERC20 contract can be obtained with getERC20). can be obtained with getERC20).*/

    function stake(
        uint256 proposalId,
        uint256 votes
    ) public onlyParticipant proposalActive(proposalId) {
        uint256 currentVotes = _proposals[proposalId]._voters[msg.sender];
        uint256 price = (currentVotes + votes) *
            (currentVotes + votes) -
            (currentVotes * currentVotes); //price in tokens without decimals()

        // No worry about reentrancy because the external contract here is of our own choice
        // And its OpenZeppelin's ERC20 which is well tested
        token.transferFrom(msg.sender, address(this), (price * (10 ** 18))); //we add the decimals for the transfer
        _proposals[proposalId]._voters[msg.sender] += votes;
        _proposals[proposalId].voteAmount += votes;
        _proposals[proposalId].currentBudget += price * tokenPrice;
        emit Events.VoteStaked(proposalId, msg.sender, votes);
        // need to not call this if its a signaling proposal because you can still vote for signaling, but
        // checkAndExecute is notSignalingProposal and it will revert everything.
        if (_proposals[proposalId].budget != 0) {
            _checkAndExecuteProposal(
                proposalId,
                _proposals[proposalId].voteAmount
            );
        }
    }

    /*withdrawFromProposal(): Given an amount of votes and the identifier of the proposal, withdraws (if possible) that amount of votes cast by the participant invoking this function from the received proposal. function from the received proposal. A participant can only withdraw from a proposal
 a proposal that he has previously cast and the proposal has not been approved or cancelled. canceled. Remember to return to the participant the tokens he used to deposit the votes he now withdraws. the votes he/she now withdraws (e.g., if he/she had deposited 4 votes for a proposal and withdraws 2, he/she will be proposal and withdraws 2, 12 tokens must be returned).*/

    function withdrawFromProposal(
        uint256 proposalId,
        uint256 votes
    ) public VotingOpen proposalActive(proposalId) {
        uint256 currentVotes = _proposals[proposalId]._voters[msg.sender];
        require(currentVotes >= votes, "Not enoughVotes to withdraw");
        uint256 price = (currentVotes * currentVotes) -
            (currentVotes - votes) *
            (currentVotes - votes);
        _proposals[proposalId].currentBudget -= price * tokenPrice;
        _proposals[proposalId]._voters[msg.sender] -= votes;
        _proposals[proposalId].voteAmount -= votes;
        // Transfers are last to leave no pending updates
        token.increaseAllowance(address(this), price * tokenPrice);
        token.transferFrom(address(this), msg.sender, (price * tokenPrice));
        emit Events.VoteWithdrawed(proposalId, msg.sender, votes);
    }

    /*_checkAndExecuteProposal(): Internal function that checks if the conditions for executing a funding proposal are met and if so, executes it using the executeProposal function of the external contract provided when creating the proposal. In this call, the money budgeted for its execution must be transferred to the contract. Remember that the budget available for proposals must be updated. (and do not forget to add to the budget the amount received from the vote tokens of the proposal just approved). In addition, the tokens associated with the votes received for the proposal should be removed, as they are consumed by the proposal execution. The signaling proposals are not approved during the voting process: they are all executed when the process is closed with closeVoting. When the call to executeProposal of the external contract is made, the maximum amount of gas it can use must be limited to prevent the proposal from consuming all the gas of the transaction. This call must consume at least 100000 gas.*/

    function _checkAndExecuteProposal(
        uint256 proposalId,
        uint256 votes
    ) internal notSignalingProposal(proposalId) {
        //checking thresholdi = (0,2 + budgeti/totalbudget) · numParticipants + numPendingProposals
        //We multiply the threshold by 100 to avoid the use of floats, we also need to multiply the votes in the comparison below
        uint256 ttlBudget = totalBudget + _proposals[proposalId].currentBudget;
        uint256 threshold = (20 +
            (_proposals[proposalId].currentBudget * 100) /
            (ttlBudget + 1)) *
            _numberOfParticipants +
            (getPendingProposals().length * 100);
        if (
            votes * 100 >= threshold &&
            ttlBudget >= _proposals[proposalId].budget
        ) {
            //TotalBudget should only consider currentbudget and publicly available budget
            token.burn(
                address(this),
                (_proposals[proposalId].currentBudget * (10 ** 18)) / tokenPrice
            );
            totalBudget -= _proposals[proposalId].budget;
            _proposals[proposalId].active = false; //We approve the proposal

            _ApprovedProposals.push(proposalId);
            
            //executeProposal is called last after all the pending updates in order to protect from reentrancy from external call
            _proposals[proposalId].proposal.executeProposal{
                value: _proposals[proposalId].budget * tokenPrice,
                gas: 100000
            }(proposalId, votes, _proposals[proposalId].budget);
            
        }
    }

    /*closeVoting(): Closes the voting period. This function can only be executed by the user who created the voting contract. When the voting period ends, the following tasks, among others, must be performed:
    - Funding proposals that could not be approved are discarded and the tokens received for those proposals are returned to their owners.
    - All signaling proposals are executed and the tokens received through votes are returned to their owners.
    - The voting budget not spent on the proposals is transferred to the owner of the voting contract.
    - When the voting process is closed, no new proposals or votes should be accepted and the QuadraticVoting contract should remain in a state that allows opening a new voting process.
    This function can consume a large amount of gas, keep this in mind when programming it and during testing. and during testing*/

    function closeVoting() public onlyOwner {
        //All signaling proposals are executed
        uint256[] memory proposalsIds = getSignalingProposals();
        for (uint256 i = 0; i < proposalsIds.length; i++) {
            _proposals[proposalsIds[i]].proposal.executeProposal(
                proposalsIds[i],
                _proposals[proposalsIds[i]].voteAmount,
                _proposals[proposalsIds[i]].currentBudget
            );
        }
        // The funds are not transfered to the owner, this is the state where voters can request their refund
        // These were kept in case optional redesign had to be reverted

        //payable(owner()).transfer(totalBudget);
        //isVotingOpen => False
        isVotingOpen = 2;
    }

    function finishVotingSession() public onlyOwner onlyRefundSession {
        //onlyRefundSession ensures that the voting session has been closed first
        //Not invested contracts budget is transfered to owners account
        payable(owner()).transfer(totalBudget);
        //isVotingOpen => 0
        isVotingOpen = 0;
        freeAll();
    }

    /* The closeVoting function will always be called before any single requestFundsReturn.
    This means that all signaling proposals have already been executed
    Question: getSignalingProposals() and getPendingProposals is only callable when voting is open - Why?
    If I want to return the funds, I need to iterate over the proposals to return the funds to the voters, cannot iterate
    if they are gone.

    "You should foresee a specific contract state in which the voting process is not open but that allows 
    the execution of the tasks related to closeVoting"

    Possible solution: Create another array with proposals that are archived:
    Put signaling and unapproved proposals in the archive so new voting can begin, the archive can be kept for
    a determined amount of time for voters to take their money back, after that the archive is also deleted for saving space
    
    Extra thoughts: If I'm worried about DOS by creation of a large amount of voters, I should be worried about DOS by
    creation of a large amount of proposals as well (especially signaling). The deletion of signaling proposals can be handled
    by using pops of the signalingProposals array. This solution is a version of resumable function where there is no
    saving index, only pop is continously used.

    */

    //function requestFundsReturn()
    function requestFundsReturn() external onlyParticipant onlyRefundSession {
        uint refund = 0;
        for (
            uint256 proposal_i = 0;
            proposal_i < numberOfProposals;
            proposal_i++
        ) {
            //Iterate through all proposals
            if (!_proposals[proposal_i].active) {
                continue;
            }
            //Pay voter_address.n_votes^2 to voter_address (amount / )
            uint votes = _proposals[proposal_i]._voters[msg.sender];
            _proposals[proposal_i].currentBudget -= votes * votes * tokenPrice;
            refund += votes * votes * tokenPrice;
        }
        _participants[msg.sender] = 0;
        //Return the tokens to the voter for later withdrawal in the token contract
        token.transfer(msg.sender, refund);
    }

    function freeAll() internal {
        //Freeing all the mappings stablishing their "size" to 0
        numberOfProposals = 0;
        _numberOfParticipants = 0;
        totalBudget = 0;
        delete _SignalingProposals;
        delete _ApprovedProposals;
        delete _PendingProposals;
    }
}

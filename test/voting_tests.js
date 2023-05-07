// npx hardhat test test/voting_tests.js

const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Voting", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  let quadraticVoting;
  async function deployVotingContract() {
    // Contracts are deployed using the first signer/account by default
    const [owner, voter, voter2] = await ethers.getSigners();

    const quadraticVoting_contract = await hre.ethers.getContractFactory("quadraticVoting");
    const quadraticVoting = await quadraticVoting_contract.deploy();

    const proposal_contract = await hre.ethers.getContractFactory("Proposal");
    const proposal = await proposal_contract.deploy();

    return { quadraticVoting, owner, voter, voter2, proposal };
  }

  // Helper function, opens the voting in the quadraticVoting contract
  async function ownerOpensVoting(quadraticVoting, owner) {
    const quadraticVoting_from_owner = await quadraticVoting.connect(owner);
    quadraticVoting_from_owner.openVoting();
  }

  // Helper function, makes the voter become a participant, takes argument for which voter
  async function voterBecomesParticipant(quadraticVoting, voter) {
    const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
    let paid_for_token = ethers.utils.parseEther("0.0000000000003");
    quadraticVoting_from_voter.addParticipant({value: paid_for_token});
  }

  async function getERC20_contract(quadraticVoting, user) {
    const quadraticVoting_from_user = await quadraticVoting.connect(user);
      const erc20_address = await quadraticVoting_from_user.getERC20();
      const erc20 = await hre.ethers.getContractAt("Stoken", erc20_address);
      // for voter
      const erc20_from_user = await erc20.connect(user);
      return erc20_from_user
  }

  describe("Deployment", function () {

    it("Should set the right owner", async function () {
      const { quadraticVoting, owner } = await loadFixture(deployVotingContract);

      expect(await quadraticVoting.owner()).to.equal(owner.address);
    });

    it("Owner should be the only one to be able to open the voting", async function () {
      const { quadraticVoting, owner, voter } = await loadFixture(deployVotingContract);
      //Try to open the voting from the owners account
      const quadraticVoting_from_owner = await quadraticVoting.connect(owner);
      await expect(quadraticVoting_from_owner.openVoting()).to.not.be.reverted;
      //Try to open the voting from the voters account
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      await expect(quadraticVoting_from_voter.openVoting()).to.be.reverted;
    });

    it("Should have the right starting balance", async function () {
      const { quadraticVoting, owner } = await loadFixture(deployVotingContract);
      const quadraticVoting_from_owner = await quadraticVoting.connect(owner);
      let starting_balance = ethers.utils.parseEther("1.0")
      quadraticVoting_from_owner.openVoting({ value: starting_balance });
      await expect(await ethers.provider.getBalance(quadraticVoting.address)).to.equal(starting_balance);
    });

    it("addParticipant(): new voter needs to spend enough ether to purchase a token", async function() {
      const { quadraticVoting, voter, voter2} = await loadFixture(deployVotingContract);
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const quadraticVoting_from_voter2 = await quadraticVoting.connect(voter2);
      let paid_for_token = ethers.utils.parseEther("0.0000000000003");
      let not_enough_for_token = ethers.utils.parseEther("0.00000000000000");
      // quadraticVoting_from_voter.addParticipant({value: paid_for_token});
      // quadraticVoting_from_voter2.addParticipant({value: not_enough_for_token});
      await expect(quadraticVoting_from_voter.addParticipant({value: paid_for_token})).to.not.be.reverted;
      await expect(quadraticVoting_from_voter2.addParticipant({value: not_enough_for_token})).to.be.reverted;
    })

    // I dont know how this doesn't fail, it should fail 100%. 
    it("removeParticipant(): removed participant cannot do actions inside the system", async function() {
      // setup
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      ownerOpensVoting(quadraticVoting, owner);
      voterBecomesParticipant(quadraticVoting, voter);
      // from voter
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const proposal_from_voter = await proposal.connect(voter);
      // voter removes himself
      await quadraticVoting_from_voter.removeParticipant();
      // tries to add signaling proposal, but really anything with onlyParticipant would work here
      expect(quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address)).to.be.reverted;
      // await expect( quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address)).to.not.be.reverted;
      voterBecomesParticipant(quadraticVoting, voter);
      expect(quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address)).to.not.be.reverted;

    })

    // // WORK IN PROGRESS
    // // it("removeParticipant(): Participant removes itself from the system, cannot function in the system anymore", async function() {
    // //   const { quadraticVoting, voter, voter2} = await loadFixture(deployVotingContract);
    // //   const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
    // //   let paid_for_token = ethers.utils.parseEther("0.0000000000003");
    // //   // quadraticVoting_from_voter.addParticipant({value: paid_for_token});
    // //   await expect(quadraticVoting_from_voter.addParticipant({value: paid_for_token})).to.not.be.reverted;
    // //   // voted added himself successfully first

    // // })
  

    //   it("Should receive and store the funds to lock", async function () {
    //     const { lock, lockedAmount } = await loadFixture(
    //       deployOneYearLockFixture
    //     );

    //     expect(await ethers.provider.getBalance(lock.address)).to.equal(
    //       lockedAmount
    //     );
    //   });

    //   it("Should fail if the unlockTime is not in the future", async function () {
    //     // We don't use the fixture here because we want a different deployment
    //     const latestTime = await time.latest();
    //     const Lock = await ethers.getContractFactory("Lock");
    //     await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //       "Unlock time should be in the future"
    //     );
    //   });
    // });

    // describe("Withdrawals", function () {
    //   describe("Validations", function () {
    //     it("Should revert with the right error if called too soon", async function () {
    //       const { lock } = await loadFixture(deployOneYearLockFixture);

    //       await expect(lock.withdraw()).to.be.revertedWith(
    //         "You can't withdraw yet"
    //       );
    //     });

    //     it("Should revert with the right error if called from another account", async function () {
    //       const { lock, unlockTime, otherAccount } = await loadFixture(
    //         deployOneYearLockFixture
    //       );

    //       // We can increase the time in Hardhat Network
    //       await time.increaseTo(unlockTime);

    //       // We use lock.connect() to send a transaction from another account
    //       await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
    //         "You aren't the owner"
    //       );
    //     });

    //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
    //       const { lock, unlockTime } = await loadFixture(
    //         deployOneYearLockFixture
    //       );

    //       // Transactions are sent using the first signer by default
    //       await time.increaseTo(unlockTime);

    //       await expect(lock.withdraw()).not.to.be.reverted;
    //     });
    //   });

    //   describe("Events", function () {
    //     it("Should emit an event on withdrawals", async function () {
    //       const { lock, unlockTime, lockedAmount } = await loadFixture(
    //         deployOneYearLockFixture
    //       );

    //       await time.increaseTo(unlockTime);

    //       await expect(lock.withdraw())
    //         .to.emit(lock, "Withdrawal")
    //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
    //     });
    //   });

    //   describe("Transfers", function () {
    //     it("Should transfer the funds to the owner", async function () {
    //       const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
    //         deployOneYearLockFixture
    //       );

    //       await time.increaseTo(unlockTime);

    //       await expect(lock.withdraw()).to.changeEtherBalances(
    //         [owner, lock],
    //         [lockedAmount, -lockedAmount]
    //       );
    //     });
    //   });
  });

  describe("Modifiers", function() {
    
  })

  describe("Proposals", function() {

    /*
    it("AddProposal(): Can only add a proposal if voting is open", async function() {
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      voterBecomesParticipant(quadraticVoting, voter);
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);

      const proposal_from_voter = await proposal.connect(voter);
      ownerOpensVoting(quadraticVoting, owner);

      // OWNER OPENED VOTING, SHOULDN'T BE REVERTED, BUT IT DOES GET REVERTED? This is why I separated the test into 2 functions, it
      // behaves weirdly sometimes, so it's best to test things separately.
      await expect(quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address)).to.be.reverted;
      // owner opens voting
      ownerOpensVoting(quadraticVoting, owner);
      quadraticVoting_from_voter2 = await quadraticVoting.connect(voter);
      await expect(quadraticVoting_from_voter2.addProposal("title", "description", 0, proposal_from_voter.address)).to.not.be.reverted;
    })
    */

    it("AddProposal(): Cannot add a proposal if voting isnt open", async function() {
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      voterBecomesParticipant(quadraticVoting, voter);
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const proposal_from_voter = await proposal.connect(voter);
      await expect(quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address)).to.be.reverted;
      quadraticVoting_from_voter2 = await quadraticVoting.connect(voter);
      // await expect(quadraticVoting_from_voter2.addProposal("title", "description", 0, proposal_from_voter.address)).to.not.be.reverted;
    })

    it("AddProposal(): Can add a proposal if voting is open", async function() {
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      ownerOpensVoting(quadraticVoting, owner);
      voterBecomesParticipant(quadraticVoting, voter);
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const proposal_from_voter = await proposal.connect(voter);
      // await expect(quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address)).to.be.reverted;
      await expect(quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address)).to.not.be.reverted;
    })

    it("OnlyParticipant(): A non-participant cannot add a proposal", async function() {
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      ownerOpensVoting(quadraticVoting, owner);
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const proposal_from_voter = await proposal.connect(voter);
      // await expect(quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address)).to.be.reverted;
      expect(quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address)).to.be.reverted;
    })

    it("AddProposal(): Successfully adds a signaling proposal", async function() {
      // setup
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      ownerOpensVoting(quadraticVoting, owner);
      voterBecomesParticipant(quadraticVoting, voter);
      // from voter
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const proposal_from_voter = await proposal.connect(voter);
      // adds a signaling proposal, 3rd argument is 0
      await quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address);
      // first added proposal has an index of 1
      let bigNumber1 = ethers.BigNumber.from(1);
      expect((await quadraticVoting_from_voter.getSignalingProposals()).length).to.equal(bigNumber1);
    })

    it("AddProposal(): Successfully adds a funding proposal", async function() {
      // setup
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      ownerOpensVoting(quadraticVoting, owner);
      voterBecomesParticipant(quadraticVoting, voter);
      // from voter
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const proposal_from_voter = await proposal.connect(voter);
      // adds a signaling proposal, 3rd argument is 0
      await quadraticVoting_from_voter.addProposal("title", "description", 20, proposal_from_voter.address);
      // first added proposal has an index of 1
      let bigNumber1 = ethers.BigNumber.from('1');
      expect((await quadraticVoting_from_voter.getPendingProposals()).length).to.equal(bigNumber1);
    })

    it("getSignalingProposals(): Returns empty array if no proposals", async function() {
      // setup
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      ownerOpensVoting(quadraticVoting, owner);
      voterBecomesParticipant(quadraticVoting, voter);
      // from voter
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      expect((await quadraticVoting_from_voter.getSignalingProposals()).length).to.equal(0);
    })

    it("getPendingProposals(): Returns empty array if no proposals", async function() {
      // setup
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      ownerOpensVoting(quadraticVoting, owner);
      voterBecomesParticipant(quadraticVoting, voter);
      // from voter
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      expect((await quadraticVoting_from_voter.getPendingProposals()).length).to.equal(0);
    })

    // Needs to change if we change getProposalInfo()
    it("GetProposalInfo(): Returns proposal info", async function() {
      // setup
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      ownerOpensVoting(quadraticVoting, owner);
      voterBecomesParticipant(quadraticVoting, voter);
      // from voter
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const proposal_from_voter = await proposal.connect(voter);
      // adds a funding proposal of budget 20
      budget = 20;
      BN_budget = ethers.BigNumber.from(budget);
      await quadraticVoting_from_voter.addProposal("title", "description", budget, proposal_from_voter.address);
      const output = await quadraticVoting_from_voter.getProposalInfo(1);
      expected_output = "title: title\ndescription: description"
      // first added proposal has an index of 1
      expect(output).to.equal(expected_output);
    })

    it("CancelProposal(): Only the creator of a proposal can cancel it", async function() {
      // setup
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      ownerOpensVoting(quadraticVoting, owner);
      voterBecomesParticipant(quadraticVoting, voter);
      // from voter
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const proposal_from_voter = await proposal.connect(voter);
      // voter adds a proposals
      await quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address);

      // voter2 tries to cancel it, he cannot
      voterBecomesParticipant(quadraticVoting, voter2);
      const quadraticVoting_from_voter2 = await quadraticVoting.connect(voter2);
      expect(await quadraticVoting_from_voter.cancelProposal(1)).to.be.reverted;

      // voter cancels it
      expect(await quadraticVoting_from_voter.cancelProposal(1)).to.not.be.reverted;
    })

  });

  describe("Buying and selling tokens", async function() {

    it("addParticipant(): user starts with correct amount of tokens", async function() {
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      // by default we pay exactly enough for 1 token
      voterBecomesParticipant(quadraticVoting, voter);
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const erc20_address = await quadraticVoting_from_voter.getERC20();
      const erc20 = await hre.ethers.getContractAt("Stoken", erc20_address);
      const erc20_from_voter = await erc20.connect(voter);

      // 1x1 + 18x0
      BN_balance = ethers.BigNumber.from('1000000000000000000');
      expect((await erc20_from_voter.balanceOf(voter.address))).to.equal(BN_balance);
    })

    it("buyTokens(): User buys an additional token", async function () {
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      // by default we pay exactly enough for 1 token
      voterBecomesParticipant(quadraticVoting, voter);
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      // getting erc20
      const erc20_from_voter = await getERC20_contract(quadraticVoting, voter);

      // 1x1 + 18x0
      BN_balance = ethers.BigNumber.from('1000000000000000000');
      // starting token balance after joining the quadraticVoting
      expect((await erc20_from_voter.balanceOf(voter.address))).to.equal(BN_balance);

      // paying for 1 more token
      let eth_for_1_token = ethers.utils.parseEther("0.0000000000003");
      await quadraticVoting_from_voter.buyTokens({value: eth_for_1_token});

      // 1x2 + 18x0
      BN_balance2 = ethers.BigNumber.from('2000000000000000000');
      // token balance after buying an additional token
      expect((await erc20_from_voter.balanceOf(voter.address))).to.equal(BN_balance2);
    })

    it("sellTokens(): Voter sells a token", async function() {
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      // by default we pay exactly enough for 1 token
      voterBecomesParticipant(quadraticVoting, voter);
      // block for getting erc20
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const erc20_address = await quadraticVoting_from_voter.getERC20();
      const erc20 = await hre.ethers.getContractAt("Stoken", erc20_address);
      // for voter
      const erc20_from_voter = await erc20.connect(voter);

      // 1x1 + 18x0
      BN_balance = ethers.BigNumber.from('1000000000000000000');
      // starting token balance after joining the quadraticVoting
      expect((await erc20_from_voter.balanceOf(voter.address))).to.equal(BN_balance);

      // now selling 1 token
      quadraticVoting_from_voter.sellTokens(BN_balance);

      BN_balance2 = ethers.BigNumber.from('0');
      expect((await erc20_from_voter.balanceOf(voter.address))).to.equal(BN_balance2);
    })

    it("sellTokens(): Voter cannot sell more tokens than he owns token", async function() {
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      // by default we pay exactly enough for 1 token
      voterBecomesParticipant(quadraticVoting, voter);
      // block for getting erc20
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      // for voter
      const erc20_from_voter = await getERC20_contract(quadraticVoting, voter);

      // 1x1 + 18x0
      BN_balance = ethers.BigNumber.from('1000000000000000000');
      // starting token balance after joining the quadraticVoting
      expect((await erc20_from_voter.balanceOf(voter.address))).to.equal(BN_balance);

      // now selling 5 tokens
      BN_balance2 = ethers.BigNumber.from('5000000000000000000');
      expect(quadraticVoting_from_voter.sellTokens(BN_balance2)).to.be.reverted;
      // still has the same balance after unsuccessful sale of tokens
      expect((await erc20_from_voter.balanceOf(voter.address))).to.equal(BN_balance);
    })
  })

  describe("Voting tests", async function() {
    it("Voter can vote", async function() {
      // initial setup
      const {quadraticVoting, owner, voter, voter2, proposal } = await loadFixture(deployVotingContract);
      voterBecomesParticipant(quadraticVoting, voter);
      ownerOpensVoting(quadraticVoting, owner);
      // contracts connected to voter
      const proposal_from_voter = await proposal.connect(voter);
      const quadraticVoting_from_voter = await quadraticVoting.connect(voter);
      const erc20_from_voter = await getERC20_contract(quadraticVoting, voter);
      
      // adds a signaling proposal to vote into
      await quadraticVoting_from_voter.addProposal("title", "description", 0, proposal_from_voter.address);
      // just checking that its index is 1
      let bigNumber1 = ethers.BigNumber.from(1);
      expect((await quadraticVoting_from_voter.getSignalingProposals()).length).to.equal(bigNumber1);

      // user has 1 token at start, needs to approve it for use first
      BN_balance = ethers.BigNumber.from('1000000000000000000');
      expect((await erc20_from_voter.balanceOf(voter.address))).to.equal(BN_balance);

      // if user didnt approve the allowance, he cannot vote, it will be reverted
      expect(quadraticVoting_from_voter.stake(1, 1)).to.be.reverted;

      //approving use of tokens by the user, to the quadraticVoting
      BN_balance2 = ethers.BigNumber.from('1000000000000000000');
      await erc20_from_voter.approve(quadraticVoting.address, BN_balance2);

      //number of votes in the proposal before the vote happened is 0.
      expect( await quadraticVoting_from_voter.getProposalInfo_voteAmount(1)).is.equal(ethers.BigNumber.from(0))

      //voting to proposal 1, with whole balance (1 token)
      await quadraticVoting_from_voter.stake(1, 1);

      // number of votes in the proposal after the vote happened.
      expect( await quadraticVoting_from_voter.getProposalInfo_voteAmount(1)).is.equal(ethers.BigNumber.from(1))

      // TODO did transfer actually happen
      // TODO currentBudget is 1 * tokenPrice
      // add test here
  
      // voter goes to vote again, this time it should cost 3 tokens to cast a single vote
      // buying tokens, approving the allowance
      let eth_for_3_token = ethers.utils.parseEther("0.0000000000009");
      await quadraticVoting_from_voter.buyTokens({value: eth_for_3_token});
      BN_balance3 = ethers.BigNumber.from('3000000000000000000');
      await erc20_from_voter.approve(quadraticVoting.address, BN_balance3)

      // 1 more vote, costs 3 token
      await quadraticVoting_from_voter.stake(1, 1);

      // should be 2 votes inside
      expect( await quadraticVoting_from_voter.getProposalInfo_voteAmount(1)).is.equal(ethers.BigNumber.from(2))

      // TODO currentBudget is 4 * tokenPrice
      // transfer happened, user lost correct amount of money
      


    })


  })


});

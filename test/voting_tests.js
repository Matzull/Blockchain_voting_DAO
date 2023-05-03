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
    const [owner, voter] = await ethers.getSigners();

    const quadraticVoting_contract = await hre.ethers.getContractFactory("quadraticVoting");
    const quadraticVoting = await quadraticVoting_contract.deploy();

    return { quadraticVoting, owner, voter };
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
});

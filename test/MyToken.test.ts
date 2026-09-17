import { expect } from 'chai';
import { ethers } from 'hardhat';
import { MyToken } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('MyToken', function () {
  let token: MyToken;
  let owner: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;

  const NAME = 'MyToken';
  const SYMBOL = 'MTK';
  const SUPPLY = ethers.parseEther('1000000');

  beforeEach(async function () {
    [owner, alice, bob] = await ethers.getSigners();
    const Token = await ethers.getContractFactory('MyToken');
    token = await Token.deploy(NAME, SYMBOL, 18, SUPPLY);
  });

  describe('Deployment', function () {
    it('should set name, symbol and decimals correctly', async function () {
      expect(await token.name()).to.equal(NAME);
      expect(await token.symbol()).to.equal(SYMBOL);
      expect(await token.decimals()).to.equal(18);
    });

    it('should mint initial supply to owner', async function () {
      expect(await token.totalSupply()).to.equal(SUPPLY);
      expect(await token.balanceOf(owner.address)).to.equal(SUPPLY);
    });
  });

  describe('transfer()', function () {
    it('should transfer tokens and emit Transfer event', async function () {
      const amount = ethers.parseEther('100');
      await expect(token.transfer(alice.address, amount))
        .to.emit(token, 'Transfer')
        .withArgs(owner.address, alice.address, amount);
      expect(await token.balanceOf(alice.address)).to.equal(amount);
      expect(await token.balanceOf(owner.address)).to.equal(SUPPLY - amount);
    });

    it('should revert with InsufficientBalance if sender has not enough', async function () {
      await expect(
        token.connect(alice).transfer(bob.address, ethers.parseEther('1'))
      ).to.be.revertedWithCustomError(token, 'InsufficientBalance');
    });

    it('should revert with ZeroAddress if recipient is address(0)', async function () {
      await expect(
        token.transfer(ethers.ZeroAddress, ethers.parseEther('1'))
      ).to.be.revertedWithCustomError(token, 'ZeroAddress');
    });
  });

  describe('approve() and transferFrom()', function () {
    it('should allow transferFrom after approve', async function () {
      const amount = ethers.parseEther('500');
      await token.approve(alice.address, amount);
      await token.connect(alice).transferFrom(owner.address, bob.address, amount);
      expect(await token.balanceOf(bob.address)).to.equal(amount);
      expect(await token.allowance(owner.address, alice.address)).to.equal(0);
    });

    it('should revert if allowance exceeded', async function () {
      await token.approve(alice.address, ethers.parseEther('100'));
      await expect(
        token.connect(alice).transferFrom(owner.address, bob.address, ethers.parseEther('101'))
      ).to.be.revertedWithCustomError(token, 'InsufficientAllowance');
    });

    it('should support infinite approval (uint256.max)', async function () {
      await token.approve(alice.address, ethers.MaxUint256);
      const amount = ethers.parseEther('100');
      await token.connect(alice).transferFrom(owner.address, bob.address, amount);
      expect(await token.allowance(owner.address, alice.address)).to.equal(ethers.MaxUint256);
    });
  });

  describe('mint() and burn()', function () {
    it('owner can mint additional tokens', async function () {
      const amount = ethers.parseEther('1000');
      await token.mint(alice.address, amount);
      expect(await token.balanceOf(alice.address)).to.equal(amount);
      expect(await token.totalSupply()).to.equal(SUPPLY + amount);
    });

    it('non-owner cannot mint', async function () {
      await expect(
        token.connect(alice).mint(alice.address, ethers.parseEther('1000'))
      ).to.be.revertedWithCustomError(token, 'Unauthorized');
    });

    it('any user can burn their own tokens', async function () {
      const amount = ethers.parseEther('100');
      await token.transfer(alice.address, amount);
      await token.connect(alice).burn(amount);
      expect(await token.balanceOf(alice.address)).to.equal(0);
      expect(await token.totalSupply()).to.equal(SUPPLY - amount);
    });
  });

  describe('transferOwnership()', function () {
    it('owner can transfer ownership and emit event', async function () {
      await expect(token.transferOwnership(alice.address))
        .to.emit(token, 'OwnershipTransferred')
        .withArgs(owner.address, alice.address);
      expect(await token.owner()).to.equal(alice.address);
    });

    it('reverts on zero address', async function () {
      await expect(
        token.transferOwnership(ethers.ZeroAddress)
      ).to.be.revertedWithCustomError(token, 'ZeroAddress');
    });

    it('non-owner cannot transfer ownership', async function () {
      await expect(
        token.connect(alice).transferOwnership(bob.address)
      ).to.be.revertedWithCustomError(token, 'Unauthorized');
    });
  }); 
});
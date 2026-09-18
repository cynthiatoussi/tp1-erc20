// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import 'forge-std/Test.sol';
import '../contracts/MyToken.sol';

contract MyTokenTest is Test {
    MyToken token;
    address owner = makeAddr('owner');
    address alice = makeAddr('alice');
    address bob = makeAddr('bob');
    uint256 SUPPLY = 1_000_000 ether;

    function setUp() public {
        vm.prank(owner);
        token = new MyToken('MyToken', 'MTK', 18, SUPPLY);

        // L'invariant ne doit pas etre casse par mint/burn :
        // on restreint le fuzzer aux fonctions qui ne changent pas totalSupply.
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MyToken.transfer.selector;
        selectors[1] = MyToken.approve.selector;
        selectors[2] = MyToken.transferFrom.selector;
        targetSelector(FuzzSelector({addr: address(token), selectors: selectors}));
    }

    // --- Tests unitaires ---
    function test_InitialState() public view {
        assertEq(token.name(), 'MyToken');
        assertEq(token.symbol(), 'MTK');
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(owner), SUPPLY);
    }

    function test_Transfer() public {
        uint256 amount = 100 ether;
        vm.prank(owner);
        token.transfer(alice, amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(owner), SUPPLY - amount);
    }

    function test_RevertIf_InsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MyToken.InsufficientBalance.selector, 0, 1 ether)
        );
        token.transfer(bob, 1 ether);
    }

        // --- Tests unitaires complementaires (couverture) ---
    function test_TransferRevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(MyToken.ZeroAddress.selector);
        token.transfer(address(0), 1 ether);
    }

    function test_Approve() public {
        vm.prank(owner);
        token.approve(alice, 500 ether);
        assertEq(token.allowance(owner, alice), 500 ether);
    }

    function test_ApproveRevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(MyToken.ZeroAddress.selector);
        token.approve(address(0), 1 ether);
    }

    function test_TransferFrom() public {
        vm.prank(owner);
        token.approve(alice, 500 ether);
        vm.prank(alice);
        token.transferFrom(owner, bob, 200 ether);
        assertEq(token.balanceOf(bob), 200 ether);
        assertEq(token.allowance(owner, alice), 300 ether);
    }

    function test_TransferFromInfiniteApproval() public {
        vm.prank(owner);
        token.approve(alice, type(uint256).max);
        vm.prank(alice);
        token.transferFrom(owner, bob, 100 ether);
        assertEq(token.allowance(owner, alice), type(uint256).max);
    }

    function test_TransferFromRevertsIfAllowanceExceeded() public {
        vm.prank(owner);
        token.approve(alice, 100 ether);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MyToken.InsufficientAllowance.selector, 100 ether, 101 ether)
        );
        token.transferFrom(owner, bob, 101 ether);
    }

    function test_TransferFromRevertsOnZeroAddress() public {
        vm.prank(owner);
        token.approve(alice, 100 ether);
        vm.prank(alice);
        vm.expectRevert(MyToken.ZeroAddress.selector);
        token.transferFrom(owner, address(0), 10 ether);
    }

    function test_MintByOwner() public {
        vm.prank(owner);
        token.mint(alice, 1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);
        assertEq(token.totalSupply(), SUPPLY + 1000 ether);
    }

    function test_MintRevertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(MyToken.Unauthorized.selector);
        token.mint(alice, 1000 ether);
    }

    function test_MintRevertsOnZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(MyToken.ZeroAmount.selector);
        token.mint(alice, 0);
    }

    function test_MintRevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(MyToken.ZeroAddress.selector);
        token.mint(address(0), 1 ether);
    }

    function test_Burn() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        vm.prank(alice);
        token.burn(40 ether);
        assertEq(token.balanceOf(alice), 60 ether);
        assertEq(token.totalSupply(), SUPPLY - 40 ether);
    }

    function test_BurnRevertsIfInsufficient() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MyToken.InsufficientBalance.selector, 0, 1 ether)
        );
        token.burn(1 ether);
    }

    function test_TransferOwnership() public {
        vm.prank(owner);
        token.transferOwnership(alice);
        assertEq(token.owner(), alice);
    }

    function test_TransferOwnershipRevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(MyToken.ZeroAddress.selector);
        token.transferOwnership(address(0));
    }

    function test_TransferOwnershipRevertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(MyToken.Unauthorized.selector);
        token.transferOwnership(bob);
    }

    // --- Tests de fuzzing ---
    function testFuzz_TransferConservesTotalSupply(
        address to,
        uint256 amount
    ) public {
        vm.assume(to != address(0) && to != owner);
        amount = bound(amount, 0, SUPPLY);
        uint256 totalBefore = token.totalSupply();
        vm.prank(owner);
        token.transfer(to, amount);
        assertEq(token.totalSupply(), totalBefore);
    }

    function testFuzz_ApproveAndTransferFrom(
        uint256 approveAmt,
        uint256 transferAmt
    ) public {
        approveAmt = bound(approveAmt, 0, SUPPLY);
        transferAmt = bound(transferAmt, 0, SUPPLY);

        vm.prank(owner);
        token.approve(alice, approveAmt);

        if (transferAmt > approveAmt) {
            vm.prank(alice);
            vm.expectRevert(
                abi.encodeWithSelector(
                    MyToken.InsufficientAllowance.selector, approveAmt, transferAmt
                )
            );
            token.transferFrom(owner, bob, transferAmt);
        } else {
            vm.prank(alice);
            token.transferFrom(owner, bob, transferAmt);
            assertEq(token.balanceOf(bob), transferAmt);
        }
    }

    // --- Invariant ---
    function invariant_totalSupplyIsConsistent() public view {
        assertEq(token.totalSupply(), SUPPLY);
    }
}
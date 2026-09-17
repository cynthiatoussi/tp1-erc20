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
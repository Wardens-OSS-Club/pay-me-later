// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {PayMeLater} from "src/PayMeLater.sol";

contract MockERC20 is ERC20{
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_){
    }

    function mint(address to, uint256 amt) external {
      _mint(to, amt);
    }
}

contract PayMeLaterTests is Test {
  MockERC20 token;
  PayMeLater tool;

  function setUp() public {
    token = new MockERC20("Mock", "M");
    tool = new PayMeLater();
  }

  address user = address(this);
  address recipient = address(0x123);
  address attacker = address(0xb4d);

  function testCreatePayment() public {
    token.mint(user, 2e18);
    token.approve(address(tool), 2e18);
    uint256 nonceToCancel = tool.startDelayedPayment(recipient, address(token), 1e18, 100);
    uint256 nonceToKeep = tool.startDelayedPayment(recipient, address(token), 1e18, 100);

    // Assert that you cannot claim now
    // Assert that recipient cannot claim now
    // Assert that attacker cannot claim now
    vm.expectRevert("Payment must exist");
    vm.prank(address(this));
    tool.claimPaymentAfterExpiry(nonceToCancel);

    vm.expectRevert("Payment must exist");
    vm.prank(address(attacker));
    tool.claimPaymentAfterExpiry(nonceToCancel);

    console2.log("block.timestamp", block.timestamp);
    vm.expectRevert("Delay must have passed");
    vm.prank(address(recipient));
    tool.claimPaymentAfterExpiry(nonceToCancel);

    // TODO: fuzz of creation
    (address c, address t, uint256 amt, uint256 deadline) = tool.delayedPaymentInfo(recipient, 0);
    console2.log("deadline", deadline);

    console2.log("block.timestamp", block.timestamp);
    vm.expectRevert("Delay must have passed");
    vm.prank(address(recipient));
    tool.claimPaymentAfterExpiry(nonceToKeep);
    console2.log("block.timestamp", block.timestamp);

    // Attacker cannot cancel
    // Recipient cannot cancel
    // Assert that you can cancel
    vm.expectRevert("Must be creator");
    vm.prank(address(recipient));
    tool.cancelDelayedPayment(recipient, nonceToCancel);

    vm.expectRevert("Must be creator");
    vm.prank(address(attacker));
    tool.cancelDelayedPayment(recipient, nonceToCancel);

    // This will work
    uint256 balB4 = token.balanceOf(address(this));
    vm.prank(address(this));
    tool.cancelDelayedPayment(recipient, nonceToCancel);
    uint256 balAfter = token.balanceOf(address(this));
    assertEq(balAfter - balB4, 1e18, "Cancelled as intended"); // I got 1e18 back

    vm.expectRevert("Payment must exist");
    vm.prank(address(this));
    tool.cancelDelayedPayment(recipient, nonceToCancel);


    vm.warp(block.timestamp + 100);
    // Wait
    // You cannot receive
    // Attacke cannot receive
    // Recipient can receive

    // Payment that we canceled doesn't exist
    vm.expectRevert("Payment must exist");
    vm.prank(address(recipient));
    tool.claimPaymentAfterExpiry(nonceToCancel);

    vm.expectRevert("Payment must exist");
    vm.prank(address(this));
    tool.claimPaymentAfterExpiry(nonceToCancel);

    vm.expectRevert("Payment must exist");
    vm.prank(address(this));
    tool.claimPaymentAfterExpiry(nonceToKeep);

    vm.expectRevert("Payment must exist");
    vm.prank(address(attacker));
    tool.claimPaymentAfterExpiry(nonceToCancel);

    vm.expectRevert("Payment must exist");
    vm.prank(address(attacker));
    tool.claimPaymentAfterExpiry(nonceToKeep);

    // Recipient can claim valid
    balB4 = token.balanceOf(recipient);
    vm.prank(address(recipient));
    tool.claimPaymentAfterExpiry(nonceToKeep);
    balAfter = token.balanceOf(recipient);
    assertEq(balAfter - balB4, 1e18, "Matches what was sent");
  }
}
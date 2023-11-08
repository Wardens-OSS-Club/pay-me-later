
// SPDX-License Identifier: MIT

pragma solidity 0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Don't use weird tokens ffs
contract PayMeLater {
  using SafeERC20 for IERC20;

  
  struct DelayedPayment {
    address creator;
    address token;
    uint256 amount;
    uint256 deadline;
  }

  mapping (address recipient => uint256 nonce) public nonces;

  mapping (address recipient => mapping (uint256 nonces => DelayedPayment paymentData)) public delayedPaymentInfo;


  uint256 private constant ZERO = 0;
  


  /// @notice Initiate a delayed payment
  function startDelayedPayment(address recipient, address token, uint256 amount, uint256 secondsDelayFromNow) external returns (uint256) {
    require(secondsDelayFromNow > ZERO); // Use a transfer if you don't want a delay

    // Cache the user nonce, then update it
    uint256 cachedNonce = nonces[recipient]++;

    delayedPaymentInfo[recipient][cachedNonce] = DelayedPayment({
      creator: msg.sender,
      token: token,
      amount: amount,
      deadline: block.timestamp + secondsDelayFromNow
    });

    IERC20 cachedToken = IERC20(token);
    uint256 startBal = cachedToken.balanceOf(address(this));
    cachedToken.safeTransfer(msg.sender, amount);
    uint256 newBal = cachedToken.balanceOf(address(this));
    require(newBal - startBal == amount); // No FoT

    return cachedNonce;
  }

  /// @notice Cancel a delayed payment, if you made a typo
  ///   Returns the Token and the Amount
  function cancelDelayedPayment(address recipient, uint256 nonce) external returns (address, uint256) {
    DelayedPayment storage paymentData = delayedPaymentInfo[recipient][nonce];
    require(paymentData.creator == msg.sender); // Can be cancelled even when matured, this is supposed to be used for people you trust

    // Get the data
    IERC20 cachedToken = IERC20(paymentData.token);
    uint256 cachedAmount = paymentData.amount;


    // Reset to 0 for refunds
    paymentData.creator = address(uint160(ZERO));
    paymentData.amount = ZERO;
    paymentData.deadline = ZERO;
    paymentData.token = address(uint160(ZERO));


    // Transfer the token
    cachedToken.safeTransfer(msg.sender, cachedAmount);

    return (address(cachedToken), cachedAmount);
  }

  /// @notice Perform the payment without waiting for the delay, after the recipient has confirmed it's them
  ///   Returns the Recipient, Token and the Amount
  function confirmDelayedPayment(address recipient, uint256 nonce) external returns (address, address, uint256) {
    // Only initiator can do it
    // Basically same logic as below
    DelayedPayment storage paymentData = delayedPaymentInfo[recipient][nonce];
    require(paymentData.creator == msg.sender); // Can be cancelled even when matured, this is supposed to be used for people you trust

    // Get the data
    IERC20 cachedToken = IERC20(paymentData.token);
    uint256 cachedAmount = paymentData.amount;


    // Reset to 0 for refunds
    paymentData.creator = address(uint160(ZERO));
    paymentData.amount = ZERO;
    paymentData.deadline = ZERO;
    paymentData.token = address(uint160(ZERO));


    // Transfer the token
    cachedToken.safeTransfer(recipient, cachedAmount);

    return (recipient, address(cachedToken), cachedAmount);
  }


  /// @notice Claim a payment after the delay time
  ///   Returns the Token and the Amount
  function claimPaymentAfterExpiry(uint256 nonce) external returns (address, uint256) {
    // Process the payment, zero out the values

    DelayedPayment storage paymentData = delayedPaymentInfo[msg.sender][nonce];

    uint256 cachedDeadline = paymentData.deadline;

    require(cachedDeadline != ZERO);
    require(cachedDeadline >= block.timestamp);

    IERC20 cachedToken = IERC20(paymentData.token);
    uint256 cachedAmount = paymentData.amount;

    // Reset to 0 for refunds
    paymentData.creator = address(uint160(ZERO));
    paymentData.amount = ZERO;
    paymentData.deadline = ZERO;
    paymentData.token = address(uint160(ZERO));


    // Transfer the token
    cachedToken.safeTransfer(msg.sender, cachedAmount);

    return (address(cachedToken), cachedAmount);
  }
}
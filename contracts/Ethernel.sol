// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/// @title A guessing game based on token prices.
/// @author Matin Kaboli
/// @dev Contract needs auditing. Do not use at production.
contract Ethernel {
  /// Bet status. PENDING by default.
  enum BetStatus {
    PENDING,
    EXPIRED,
    CANCELED,
    ACCEPTED,
    COMPLETED
  }

  enum Token {
    BTC,
    ETH,
    BNB,
    XRP,
    ADA,
    SOL
  }

  /// Winner status. UNKNOWN by default.
  enum Winner {
    UNKNOWN,
    REQUESTER,
    ACCEPTOR
  }

  /**
   * @member betAmount The amount that each participant pays to enter the bet.
   * @member token The selected token that its price is going to be predicted.
   * @member predictedPrice The predicted price for the selected token at the specified date. 
   * @member isGt If the requester predicts that the price is going to be GREATER than
   * predicted price at the specified date, then isGt is true. The opposite applies for acceptor.
   * @member specifiedDate The date specified by requester that the price of the selected token
   * will be checked at that time.
   * @member expirationDate The date that this bet expires (If not accepted by anyone at that time.)
   * @member requester Creator and owner and a participant of the bet.
   * @member acceptor The other participant of the bet..
   * @member status Status of the bet, PENDING by default.
   * @member winner Winner of the bet, UNKNOWN by default.
   */
  struct Bet {
    uint betAmount; 

    Token token;
    uint predictedPrice;
    bool isGt;

    uint specifiedDate;
    uint expirationDate;

    address payable requester;
    address payable acceptor;

    BetStatus status;
    Winner winner; 
  }

  uint8 private constant MAX_PENDING_BETS = 5;
  uint private constant MINIMUM_BET_AMOUNT = (1 ether) * 0.001;

  Bet[] private bets;
  mapping(uint => address) private betToOwner;
  mapping (address => uint) private ownerPendingBets;

  /// @notice Fires when a new bet is created.
  event BetCreated(
    uint betId,
    uint betAmount,
    Token token,
    uint predictedPrice,
    bool isGt,
    uint specifiedDate,
    uint expirationDate,
    address requester
  );

  /// @notice Fires when a pending bet is canceled.
  event BetCanceled(uint betId, uint betAmount);

  /// @notice Fires when a pending bet is accepted.
  event BetAccepted(uint betId, address acceptor);

  /// @notice Creates a new bet
  /// @param token The selected token that its price is going to be predicted.
  /// @param predictedPrice The predicted price for the selected token at the specified date. 
  /// @param isGt Whether requester wants to guess for higher price or not.
  /// @param specifiedDate The date specified by requester to check the price at that time
  /// @param expirationDate The date that this bet expires (If not accepted by anyone at that time.)
  /// @return Bet ID
  function createBet(Token token, uint predictedPrice, bool isGt, uint specifiedDate, uint expirationDate) payable public returns (uint) {
    // Avoid having too much pending bets
    require(ownerPendingBets[msg.sender] <= MAX_PENDING_BETS, "You have reached the limit of pending bets.");
    require(msg.value >= MINIMUM_BET_AMOUNT, "Sent value must be more than minimum amount");
    // dates must be higher than current timestamp.
    require(expirationDate > block.timestamp, "Expiration date must be greater than current timestamp.");
    require(specifiedDate > block.timestamp, "Specified date must be greater than current timestamp.");
    require(expirationDate < specifiedDate, "Expiration date must be less than specified date.");

    Bet memory newBet = Bet(
      msg.value,
      token,
      predictedPrice,
      isGt,
      specifiedDate,
      expirationDate,
      payable(msg.sender),
      payable(address(0)),
      BetStatus.PENDING,
      Winner.UNKNOWN
    );

    bets.push(newBet);

    uint betId = bets.length;

    ownerPendingBets[msg.sender]++;
    betToOwner[betId] = msg.sender;

    emit BetCreated(betId, msg.value, token, predictedPrice, isGt, specifiedDate, expirationDate, msg.sender);

    return betId;
  }

  /// @notice Cancels a pending bet
  /// @dev reverts if transferring ETH to requester fails
  /// @param betId Bet ID is used for canceling
  function cancelBet(uint betId) public returns (bool) {
    Bet storage _bet = bets[betId];

    require(_bet.status == BetStatus.PENDING, "Bet is not pending, so it cannot be canceled.");
    require(_bet.expirationDate > block.timestamp, "Expiration date has passed. Bet cannot be canceled.");
    require(_bet.requester == msg.sender, "You are not the owner of this bet.");

    _bet.status = BetStatus.CANCELED;

    (bool success,) = _bet.requester.call{value: _bet.betAmount}('');

    emit BetCanceled(betId, _bet.betAmount);
    ownerPendingBets[msg.sender]--;

    require(success, "Failed to withdraw requester balance.");

    return true;
  }

  /// @notice Accepts a pending bet from acceptor 
  /// @return true if succeeds
  function acceptBet(uint betId) public payable returns (bool) {
    Bet storage _bet = bets[betId];

    require(_bet.status == BetStatus.PENDING, "Bet is not pending, therefore cannot be accepted.");
    // Acceptor should also send the same amount of ETH as requester did
    require(_bet.betAmount == msg.value, "Sent value does not match bet amount.");
    require(_bet.requester != msg.sender, "You cannot join your own bet.");
    require(_bet.expirationDate > block.timestamp, "Expiration date has passed. Bet cannot be accepted.");
    require(_bet.specifiedDate > block.timestamp, "Specified date has passed. Bet cannot be accepted.");

    _bet.status = BetStatus.ACCEPTED;
    _bet.acceptor = payable(msg.sender);

    emit BetAccepted(betId, msg.sender);

    return true;
  }
}

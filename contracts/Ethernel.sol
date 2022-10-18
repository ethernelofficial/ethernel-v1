// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./PriceAggregator.sol";

/// @title A guessing game based on token prices.
/// @author Matin Kaboli
/// @dev Contract needs auditing. Do not use at production.
/// @dev Inherits the OpenZepplin Ownable implentation
/// @dev Requires a new function to set the new PriceAggregator contract address
/// @dev Requires a new function to set the new MAX_PENDING_BETS and FEE_PERCENTAGE
contract Ethernel is Ownable {
  uint8 private FEE_PERCENTAGE = 1;
  uint8 private MAX_PENDING_BETS = 5;
  uint private constant MINIMUM_BET_AMOUNT = (1 ether) * 0.001;
  uint public contractPureBalance = 0;

  PriceAggregator private priceAggregator;
  int private btcPrice;
  int private ethPrice;
  int private bnbPrice;
  int private xrpPrice;
  int private adaPrice;
  int private solPrice;

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


  /// @notice Sends fees to the owner
  function withdraw() external onlyOwner {
    (bool success,) = payable(owner()).call{value: contractPureBalance}('');

    require(success, "Failed.");
  }

  /// @notice Changes FEE_PERCENTAGE
  /// @param _feePercentage New fee percentage received by each completed bet
  function setFeePercentage(uint8 _feePercentage) external onlyOwner {
    FEE_PERCENTAGE = _feePercentage;
  }

  /// @notice Changes MAX_PENDING_BETS
  /// @param _maxPendingBets New max amount of pending bets an address can have
  function setMaxPendingBets(uint8 _maxPendingBets) external onlyOwner {
    MAX_PENDING_BETS = _maxPendingBets;
  }

  Bet[] private bets;

  mapping (address => uint) public bettorWins;
  mapping (address => uint) public bettorLosses;
  mapping (uint => address) public betToOwner;
  mapping (address => uint) public ownerPendingBets;

  /// @notice Fires when the status of a bet changes.
  event BetStatusChanged(uint betId, BetStatus status);

  /// @notice Sets PriceAggregator
  /// @param aggregator PriceAggregator contract address
  constructor(address aggregator) {
    priceAggregator = PriceAggregator(aggregator);
  }

  /// @notice Returns the current price of given token
  /// @param t Selected token
  /// @return Current price of the token
  function tokenPrice(Token t) internal view returns (int) {
    if (t == Token.BTC) {
      return btcPrice;
    }

    if (t == Token.ETH) {
      return ethPrice;
    }

    if (t == Token.BNB) {
      return bnbPrice;
    }

    if (t == Token.XRP) {
      return xrpPrice;
    }

    if (t == Token.ADA) {
      return adaPrice;
    }

    return solPrice;
  }

  /// @notice Compares actual price of the token with user's predicted price
  /// @param actualPrice The current price of the token
  /// @param predictedPrice User's predicted price
  /// @return result 0 if equal, 1 if predicted price is higher than the actual price, 2 if lower.
  function comparePrices(int actualPrice, uint predictedPrice) internal pure returns (uint8 result) {
    uint predictedPriceMultipled = predictedPrice * (10 ** 8);

    if (actualPrice == int(predictedPriceMultipled)) {
      return 0;
    }

    if (actualPrice < int(predictedPriceMultipled)) {
      return 1;
    }

    return 2;
  }

  /// @notice Retrieves the price of tokens and saves them in variables
  function setPrices() external onlyOwner {
    (int btc, int eth, int bnb, int xrp, int ada, int sol) = priceAggregator.getTokenPrices();

    btcPrice = btc;
    ethPrice = eth;
    bnbPrice = bnb;
    xrpPrice = xrp;
    adaPrice = ada;
    solPrice = sol;
  }

  /// @notice Checks if the bet is expired or ready to be finished
  /// @param betId Bet ID
  function checkBet(uint betId) external onlyOwner {
    Bet storage _bet = bets[betId];

    if (
         _bet.status == BetStatus.COMPLETED
      || _bet.status == BetStatus.EXPIRED
      || _bet.status == BetStatus.CANCELED
    ) {
      return;
    }

    if (_bet.status == BetStatus.PENDING && _bet.expirationDate < block.timestamp) {
      expireBet(betId);
    }

    if (_bet.status == BetStatus.ACCEPTED && _bet.specifiedDate > block.timestamp) {
      setWinner(betId);
    }
  } 

  /// @notice Expires a pending bet and returns held money
  /// @dev reverts if transferring ETH to requester fails
  /// @param betId Bet ID
  function expireBet(uint betId) private {
    Bet storage _bet = bets[betId];

    _bet.status = BetStatus.EXPIRED;
    
    (bool success,) = _bet.requester.call{value: _bet.betAmount}('');

    emit BetStatusChanged(betId, _bet.status);

    ownerPendingBets[_bet.requester]--;

    require(success, "Failed to send requester bet amount.");
  }

  /// @notice Retrieve a bet
  /// @return Bet
  function getBet(uint betId) external view returns (Bet memory) {
    return bets[betId];
  }

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

    emit BetStatusChanged(betId, newBet.status);

    return betId;
  }

  /// @notice Cancels a pending bet and returns held money
  /// @dev reverts if transferring ETH to requester fails
  /// @param betId Bet ID is used for canceling
  function cancelBet(uint betId) public returns (bool) {
    Bet storage _bet = bets[betId];

    require(_bet.status == BetStatus.PENDING, "Bet is not pending, so it cannot be canceled.");
    require(_bet.expirationDate > block.timestamp, "Expiration date has passed. Bet cannot be canceled.");
    require(_bet.requester == msg.sender, "You are not the owner of this bet.");

    _bet.status = BetStatus.CANCELED;

    (bool success,) = _bet.requester.call{value: _bet.betAmount}('');

    emit BetStatusChanged(betId, _bet.status);
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

    ownerPendingBets[_bet.requester]--;

    emit BetStatusChanged(betId, _bet.status);

    return true;
  }

  /// @notice Chooses the winner based on predicted price and the actual price of the token
  /// @param betId Bet ID
  function setWinner(uint betId) private {
    Bet storage _bet = bets[betId];

    int selectedTokenPrice = tokenPrice(_bet.token);
    uint8 result = comparePrices(selectedTokenPrice, _bet.predictedPrice);

    address payable winner = _bet.requester;

    if (_bet.isGt && result == 2) {
      winner = _bet.acceptor; 
    }

    if (winner == _bet.requester) {
      bettorWins[_bet.requester]++;
      bettorLosses[_bet.acceptor]++;
    } else {
      bettorWins[_bet.acceptor]++;
      bettorLosses[_bet.requester]++;
    }

    _bet.status = BetStatus.COMPLETED;

    emit BetStatusChanged(betId, _bet.status);

    uint winnerAmount = _bet.betAmount * 2;
    uint contractFee = _bet.betAmount / 100 * FEE_PERCENTAGE;
    winnerAmount -= contractFee;

    (bool success,) = winner.call{value: winnerAmount}('');
    
    require(success, "Failed to send balance to the winner.");
  }
}


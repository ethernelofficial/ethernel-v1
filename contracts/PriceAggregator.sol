// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title Retrieves prices of different tokens and returns them all at once
/// @author Matin Kaboli
/// @dev Contract needs auditing. Do not use at production.
contract PriceAggregator is Ownable {
  AggregatorV3Interface internal btcFeed;
  AggregatorV3Interface internal ethFeed;
  AggregatorV3Interface internal bnbFeed;
  AggregatorV3Interface internal xrpFeed;
  AggregatorV3Interface internal adaFeed;
  AggregatorV3Interface internal solFeed;

  /// @notice requires an AggregatorV3Interface address for each token
  /// @param _btcFeed AggregatorV3Interface contract address for BTC/USD
  /// @param _ethFeed AggregatorV3Interface contract address for ETH/USD
  /// @param _bnbFeed AggregatorV3Interface contract address for BNB/USD
  /// @param _xrpFeed AggregatorV3Interface contract address for XRP/USD
  /// @param _adaFeed AggregatorV3Interface contract address for ADA/USD
  /// @param _solFeed AggregatorV3Interface contract address for SOL/USD
  constructor(address _btcFeed, address _ethFeed, address _bnbFeed, address _xrpFeed, address _adaFeed, address _solFeed) {
    btcFeed = AggregatorV3Interface(_btcFeed);
    ethFeed = AggregatorV3Interface(_ethFeed);
    bnbFeed = AggregatorV3Interface(_bnbFeed);
    xrpFeed = AggregatorV3Interface(_xrpFeed);
    adaFeed = AggregatorV3Interface(_adaFeed);
    solFeed = AggregatorV3Interface(_solFeed);
  }

  /// @notice Changes the AggregatorV3Interface address 
  /// @param _feed AggregatorV3Interface contract address for BTC/USD
  function changeBtcFeed(address _feed) public onlyOwner {
    btcFeed = AggregatorV3Interface(_feed);
  }

  /// @notice Changes the AggregatorV3Interface address 
  /// @param _feed AggregatorV3Interface contract address for ETH/USD
  function changeEthFeed(address _feed) public onlyOwner {
    ethFeed = AggregatorV3Interface(_feed);
  }

  /// @notice Changes the AggregatorV3Interface address 
  /// @param _feed AggregatorV3Interface contract address for BNB/USD
  function changeBnbFeed(address _feed) public onlyOwner {
    bnbFeed = AggregatorV3Interface(_feed);
  }

  /// @notice Changes the AggregatorV3Interface address 
  /// @param _feed AggregatorV3Interface contract address for XRP/USD
  function changeXrpFeed(address _feed) public onlyOwner {
    xrpFeed = AggregatorV3Interface(_feed);
  }

  /// @notice Changes the AggregatorV3Interface address 
  /// @param _feed AggregatorV3Interface contract address for ADA/USD
  function changeAdaFeed(address _feed) public onlyOwner {
    adaFeed = AggregatorV3Interface(_feed);
  }

  /// @notice Changes the AggregatorV3Interface address 
  /// @param _feed AggregatorV3Interface contract address for SOL/USD
  function changeSolFeed(address _feed) public onlyOwner {
    solFeed = AggregatorV3Interface(_feed);
  }


  /// @notice Returns the prices of tokens in USD 
  /// @return BTC/USD, ETH/USD, BNB/USD, XRP/USD, ADA/USD, SOL/USD
  function getTokenPrices() public view returns (int, int, int, int, int, int) {
    (,int256 btcPrice,,,) = btcFeed.latestRoundData();
    (,int256 ethPrice,,,) = ethFeed.latestRoundData();
    (,int256 bnbPrice,,,) = bnbFeed.latestRoundData();
    (,int256 xrpPrice,,,) = xrpFeed.latestRoundData();
    (,int256 adaPrice,,,) = adaFeed.latestRoundData();
    (,int256 solPrice,,,) = solFeed.latestRoundData();

    return (btcPrice, ethPrice, bnbPrice, xrpPrice, adaPrice, solPrice);
  }
}

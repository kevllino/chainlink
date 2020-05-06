pragma solidity ^0.6.0;

import "../dev/AggregatorInterface.sol";

/**
 * @title The MockAggregator contract
 * @notice Use this contract when you need to test
 * other contract's ability to read data from an
 * aggregator contract, but how the aggregator got
 * its answer is unimportant
 */
contract MockAggregator is AggregatorInterface {
  uint8 public override decimals;
  int256 public override latestAnswer;
  uint256 public override latestTimestamp;
  uint256 public override latestRound;

  mapping(uint256 => int256) public override getAnswer;
  mapping(uint256 => uint256) public override getTimestamp;

  constructor(
    uint8 _decimals,
    int256 _initialAnswer
  ) public {
    decimals = _decimals;
    updateAnswer(_initialAnswer);
  }

  function updateAnswer(
    int256 _answer
  ) public {
    latestAnswer = _answer;
    latestTimestamp = block.timestamp;
    latestRound++;
    getAnswer[latestRound] = _answer;
    getTimestamp[latestRound] = block.timestamp;
  }

  function getRound(uint256 _roundId)
    external
    view
    override
    returns (
      uint256 roundId,
      int256 answer,
      uint64 startedAt,
      uint64 updatedAt,
      uint256 answeredInRound
    )
  {
    // TODO(kaleofduty): deal with roundId = UINT_MAX
    return (_roundId, getAnswer[_roundId], uint64(getTimestamp[_roundId]), uint64(getTimestamp[_roundId]), _roundId);
  }
}

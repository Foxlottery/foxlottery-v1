// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// chainlink
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "contracts/IRandomValueGenerator.sol";
import "contracts/ILottery.sol";

contract RandomValueGeneratorMock is IRandomValueGenerator {
    ILottery public lottery;
    uint public randomValue;

    constructor(ILottery _lottery, uint _randomValue) {
        lottery = _lottery;
        randomValue = _randomValue;
    }

    function requestRandomWords() external {
        require(msg.sender == address(lottery));
        lottery.setRandomValue(randomValue);
    }
}

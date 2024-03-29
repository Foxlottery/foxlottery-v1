// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// chainlink
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

interface IRandomValueGenerator {
    function requestRandomWords() external;
}

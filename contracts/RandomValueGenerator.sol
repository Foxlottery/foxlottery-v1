// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// chainlink
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "contracts/IRandomValueGenerator.sol";
import "contracts/ILottery.sol";

/**
 * @title Lottery
 * @author Seiya Takahashi (github: https://github.com/PeterTakahashi)
 * @notice Generate random numbers from chainlink v2. After generating random number, set that in the lottery contract.
 */
contract RandomValueGenerator is VRFConsumerBaseV2, IRandomValueGenerator {
    // chainlink vrf
    VRFCoordinatorV2Interface public COORDINATOR;
    uint64 public immutable subscriptionId;
    // chainlink vrf coordinator
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address public vrfCoordinator;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    ILottery public lottery;

    constructor(
        ILottery _lottery,
        uint64 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(vrfCoordinator)
    {
        lottery = _lottery;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = _subscriptionId;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
    }

    function fulfillRandomWords(uint256, uint256[] memory _randomWords) internal override {
        lottery.setRandomValue(_randomWords[0]);
    }

    function requestRandomWords() external {
        require(msg.sender == address(lottery));
        // Will revert if subscription is not set and funded.
        COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }
}

pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Timed Random Send Token
contract TRST is ERC20, Ownable {
    using SafeMath for uint256;
    struct RandomSendingRule {
        uint ratio;
        uint sendingCount;
    }
    struct DefinitelySendingRule {
        uint ratio;
        address destinationAddress;
    }
    uint public cycle;
    uint public closeTimestamp = block.timestamp;
    address[] public participants;
    IERC20 public erc20;
    RandomSendingRule[] public randomSendingRules;
    DefinitelySendingRule[] public definitelySendingRules;


    // Define the Lottery token contract
    constructor(string memory _name, string memory _symbol, uint _cycle, IERC20 _erc20) ERC20(_name, _symbol) {
        erc20 = _erc20;
        cycle = _cycle;
        closeTimestamp = block.timestamp + _cycle; // env: prod
    }

    function buy(uint256 _amount) public {
        require(erc20.balanceOf(msg.sender) >= _amount, "TRST: Not enough erc20 tokens.");
        _mint(msg.sender, _amount);
        participants.push(msg.sender);
        // Lock the Lottery in the contract
        erc20.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount, "TRST: Not enough erc20 tokens.");
        _burn(msg.sender, _amount);
        // unLock the Lottery in the contract
        erc20.transfer(msg.sender, _amount);
    }
     
    // 抽選の確定をするか確認
    function checkDecision() public {
        if (closeTimestamp <= block.timestamp) {
            for (uint index = 0; index < randomSendingRules.length; index++) {
                sendingDestinationDetermination(randomSendingRules[index]);
            }
            // TODO: 残りを送信するロジックを追加する
            closeTimestamp += cycle;
            delete participants; // reset participants
       }
    }

    // 当選と配当
    function sendingDestinationDetermination(RandomSendingRule memory randomSendingRule) private {
        for (uint count = 0; count < randomSendingRule.sendingCount; count++) {
            address destinationAddress = getDestinationAddress(); // 抽選の確定
            uint dividendAmount = totalSupply() / randomSendingRule.ratio;
            // 送信元が間違っている気がする
            erc20.transfer(destinationAddress, dividendAmount);
        }
    }

    function getDestinationAddress() private returns (address) {
        uint rand = getRand();
        uint totalCount = 0;
        address destinationAddress;
        for (uint i = 0; i < participants.length; i++) {
            uint participantBalance = balanceOf(participants[i]);
            totalCount += participantBalance;
            if (rand <= participantBalance) {
                destinationAddress = participants[i];
                break;
            }
         }
        return destinationAddress;
    }

    function setRandomSendingRule(uint ratio, uint sendingCount) public onlyOwner canChangeRuleByTime canSetRandomSendingRules(ratio, sendingCount) {
        randomSendingRules.push(RandomSendingRule(ratio, sendingCount));
    }

    function deleteRandomSendintRule(uint index) public onlyOwner canChangeRuleByTime {
        // Move the last element into the place to delete
        randomSendingRules[index] = randomSendingRules[randomSendingRules.length - 1];
        // Remove the last element
        randomSendingRules.pop();
    }

    modifier canSetRandomSendingRules(uint _ratio, uint _sendingCount) {
        uint totalAmount = currentRandomSendingTotal() + (10 ** 18 / _ratio) * _sendingCount;
        require(
            totalAmount < 10 ** 18, 
            "TRST: Only less than 100%"
        );
        _;
    }

    modifier canChangeRuleByTime() {
        uint elapsedTime = closeTimestamp - block.timestamp;
        require(
            block.timestamp < ((closeTimestamp - cycle) + (elapsedTime / 10)),
            "TRST: Rule changes can be made up to one-tenth of the end time."
        );
        _;
    }

    function currentRandomSendingTotal() public view returns(uint) {
        uint totalAmount = 0;
        for (uint i = 0; i < randomSendingRules.length; i++) {
            RandomSendingRule memory randomSendingRule = randomSendingRules[i];
            totalAmount += (10 ** 18 / randomSendingRule.ratio) * randomSendingRule.sendingCount;
        }
        return totalAmount;
    }

    function getRand() private returns (uint) {
        // TODO We should change
        return participants.length % block.timestamp;
    }
}
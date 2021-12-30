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
    struct SendTo {
        uint amount;
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
        require(_cycle >= 10);
        erc20 = _erc20;
        cycle = _cycle;
        closeTimestamp = block.timestamp + _cycle;
    }

    function buy(uint256 _amount) public {
        require(erc20.balanceOf(msg.sender) >= _amount, "TRST: Not enough erc20 tokens.");
        _mint(msg.sender, _amount);
        participants.push(msg.sender);
        // Lock the Lottery in the contract
        erc20.transferFrom(msg.sender, address(this), _amount);
    }
    
    // 抽選の確定をするか確認
    function randSend() public {
        require(closeTimestamp <= block.timestamp, "TRST: The time has not yet reached the closing time.");
        uint totalSupply = totalSupply();
        uint rand = getRand();
        for (uint index = 0; index < randomSendingRules.length; index++) {
            sendingDestinationDetermination(randomSendingRules[index], totalSupply, rand);
        }
        for (uint index = 0; index < definitelySendingRules.length; index++) {
            DefinitelySendingRule memory definitelySendingRule = definitelySendingRules[index];
            erc20.transfer(definitelySendingRule.destinationAddress, totalSupply / definitelySendingRule.ratio);
        }
        closeTimestamp += cycle;
        delete participants; // reset participants
    }

    // 当選と配当
    function sendingDestinationDetermination(RandomSendingRule memory randomSendingRule, uint totalSupply, uint rand) private {
        for (uint count = 0; count < randomSendingRule.sendingCount; count++) {
            uint randWithTotal = getRandWithCurrentTotal(rand);
            address destinationAddress = getDestinationAddress(randWithTotal); // 抽選の確定
            uint dividendAmount = totalSupply / randomSendingRule.ratio;
            erc20.transfer(destinationAddress, dividendAmount);
        }
    }

    function getDestinationAddress(uint randWithTotal) private view returns(address) {
        uint number = 0;
        address account;
        for (uint count = 0; count < participants.length; count++) {
            if (number < randWithTotal && randWithTotal > number + balanceOf(participants[count])) {
                account = participants[count];
                break;
            }
            number += balanceOf(participants[count]);
        }
        // Return the winner's address.
        return account;
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

    function setDefinitelySendingRule(uint ratio, address destinationAddress) public onlyOwner canChangeRuleByTime canSetDefinitelySendingRules(ratio) {
        definitelySendingRules.push(DefinitelySendingRule(ratio, destinationAddress));
    }

    function deleteDefinitelySendingRule(uint index) public onlyOwner canChangeRuleByTime {
        // Move the last element into the place to delete
        definitelySendingRules[index] = definitelySendingRules[definitelySendingRules.length - 1];
        // Remove the last element
        definitelySendingRules.pop();
    }
    
    modifier canSetRandomSendingRules(uint _ratio, uint _sendingCount) {
        uint totalAmount = currentRandomSendingTotal() + (10 ** 18 / _ratio) * _sendingCount;
        require(
            totalAmount < 10 ** 18, 
            "TRST: Only less than 100%"
        );
        _;
    }

    modifier canSetDefinitelySendingRules(uint _ratio) {
        uint totalAmount = currentRandomSendingTotal() + (10 ** 18 / _ratio);
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

    function getRandWithCurrentTotal(uint rand) public view returns (uint) {
        return getNumber(getNumber(totalSupply()) + rand);
    }

    function getRand() public view returns (uint) {
        return getNumber(getNumber(participants.length) +
                         getNumber(block.timestamp) +
                         getNumberFromAddress(participants[participants.length / 2]));
    }

    function getNumber(uint number) public view returns (uint) {
        return uint(keccak256(abi.encode(number))) % totalSupply();
    }

    function getNumberFromAddress(address account) public pure returns (uint) {
        return uint256(keccak256(abi.encodePacked(account)));
    }
}
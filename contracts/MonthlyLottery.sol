pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MonthlyLottery is ERC20("MonthlyLottery", "MLT"), Ownable {
    uint constant cycle = 30 days;
    uint closeTimestamp = block.timestamp; // env: test
    // uint closeTimestamp = block.timestamp + cycle; env: prod
    using SafeMath for uint256;
    struct WinRule {
        uint ratio;
        uint winCount;
    }
    WinRule[] winRules;
    
    IERC20 public lottery;
    address[] public participants;

    // Define the Lottery token contract
    constructor(IERC20 _lottery) public {
        lottery = _lottery;
    }

    function buy(uint256 _amount) public {
        require(lottery.balanceOf(msg.sender) >= _amount);
        _mint(msg.sender, _amount);
        participants.push(msg.sender);
        // Lock the Lottery in the contract
        lottery.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount);
        _burn(msg.sender, _amount);
        // unLock the Lottery in the contract
        lottery.transfer(msg.sender, _amount);
    }
     
    // 抽選の確定をするか確認
    function checkLotteryDecision() public {
        if (closeTimestamp <= block.timestamp) {
            for (uint index = 0; index < winRules.length; index++) {
                WinRule memory winRule = winRules[index];
                WinningAndDividend(winRule);
            }
            totalSupplytransferTolotteryOwner(); // 残りはオーナーに送信
            closeTimestamp += cycle;
       }
    }

    // 当選と配当
    function WinningAndDividend(WinRule memory winRule) private {
        for (uint count = 0; count < winRule.winCount; count++) {
            address lotteryWinner = getLotteryWinner(); // 抽選の確定
            uint dividendAmount = totalSupply() / winRule.ratio;
            console.log("lotteryWinner");
            console.log(lotteryWinner);
            console.log(dividendAmount);
            lottery.transfer(lotteryWinner, dividendAmount);
        }
    }

    function getLotteryWinner() private returns (address) {
      uint rand = getRand();
      uint totalCount = 0;
      address lotteryWinner;
      for (uint i = 0; i < participants.length; i++) {
          uint participantBalance = balanceOf(participants[i]);
          totalCount += participantBalance;
          if (rand <= participantBalance) {
              lotteryWinner = participants[i];
              break;
          }
      }
      return lotteryWinner;
    }

    function totalSupplytransferTolotteryOwner() private {
        require(totalSupply() >= 0);
        lottery.transfer(address(this), totalSupply());
        _burn(msg.sender, totalSupply());
    }

    function getRand() private returns (uint) {
        // TODO We should change
        return participants.length % block.timestamp;
    }

    function setWinRule(uint index, uint raito, uint winCount) public onlyOwner {
        winRules[index] = WinRule(raito, winCount);
    }

    function addWinRule(uint raito, uint winCount) public onlyOwner {
        winRules.push(WinRule(raito, winCount));
    }
}
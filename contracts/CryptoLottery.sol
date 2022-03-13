pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// WARNING: There is a known vuln contained within this contract related to vote delegation, 
// it's NOT recommmended to use this in production.  

contract CryptoLottery is ERC20("CryptoLottery", "CLT"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
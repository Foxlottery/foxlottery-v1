// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LotteryERC20
 * @author Peter Takahashi(CEO of LotteryERC20)
 */

contract LotteryERC20 is ERC20("LotteryERC20", "LE2"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
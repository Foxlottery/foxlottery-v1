// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestUSD
 * @author Seiya Takahashi (github: https://github.com/PeterTakahashi)
 */
contract TestUSD is ERC20("TestUSD", "TestUSD") {
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}
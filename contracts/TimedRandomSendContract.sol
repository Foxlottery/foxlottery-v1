pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";


/**
 * @title TimedRandomSendContract
 * @author Peter Takahashi(CEO of CryptoLottery)
 * @notice This smart contract collects ERC20 tokens in a single wallet and
           uses chainlink VRF to transfer the ERC20 tokens to the winners.
 */

contract TimedRandomSendContract is VRFConsumerBase, Ownable {
    struct RandomSendingRule {
        uint id;
        uint ratio;
        uint sendingCount;
    }
    struct DefinitelySendingRule {
        uint id;
        uint ratio;
        address sendingAddress;
    }
    string public name;
    string public symbol;
    uint public cycle;
    uint public closeTimestamp;
    uint public eventCounts = 0;
    address[] public participants;
    IERC20 public erc20;
    mapping(address => uint256) private _balances;

    /// RandomSendingRule
    uint[] public randomSendingRuleIds;
    mapping(uint => uint) private randomSendingRuleRatio;
    mapping(uint => uint) private randomSendingRuleSendingCount;

    /// definitelySendingRule
    uint[] public definitelySendingRuleIds;
    mapping(uint => address) private definitelySendingRuleAddress;
    mapping(uint => uint) private definitelySendingRuleRatio;
    

    // VRF Variables
    bytes32 public keyHash;
    uint256 public fee = 10 ** 17; // 0.1zz
    uint256 public randomResult;

    // Maps
    mapping(uint256 => uint256) public randomMap; // maps a eventCounts to a random number
    mapping(bytes32 => uint256) public requestMap; // maps a requestId to a eventCounts

    /**
    * @notice set initialize values
    * @param _name contract name. For example is WeeklyLottery
    * @param _symbol symbol is short name. For example is WLT 
    * @param _cycle cycle of lottery by seconds.
    * @param _erc20 ERC20 for lottery
    * @param _link ChainLink address
    * @param _coordinator ChainLink coordinator
    * @param _keyhash ChainLink keyhash
    */
    constructor(
        string memory _name,
        string memory _symbol,
        uint _cycle,
        IERC20 _erc20,
        address _link,
        address _coordinator, 
        bytes32 _keyhash)
    VRFConsumerBase(_coordinator, _link)
    {
        require(_cycle >= 10);
        name = _name;
        symbol = _symbol;
        cycle = _cycle;
        closeTimestamp = block.timestamp + _cycle;
        erc20 = _erc20;
        
        // Chainlink setters
        keyHash = _keyhash;
    }

    /**
    * @notice buy lottery ticket
    * @param _amount Amount of lottery tickets
    * @dev When you buy a lottery ticket, you lock the funds in a smart contract wallet.
    */
    function buy(uint256 _amount) public payable {
        require(erc20.balanceOf(msg.sender) >= _amount, "TimedRandomSendContract: Not enough erc20 tokens.");

        _mint(msg.sender, _amount);
        participants.push(msg.sender);

        // Lock the Lottery in the contract
        erc20.transferFrom(msg.sender, address(this), _amount);
    }
    
    /**
    * @notice random send ERC20 token to lottery participants
    */
    function randSend() public {
        // TODO: require there is randomMap[thisEventCounts] value

        require(closeTimestamp <= block.timestamp, "TimedRandomSendContract: The time has not yet reached the closing time.");
        uint constantTotalSupply = totalSupply();
        uint rand = getRand();

        // random send
        for (uint index = 0; index < randomSendingRuleIds.length; index++) {
            uint id = randomSendingRuleIds[index];
            if (id == 0) { continue; }
            uint ratio = randomSendingRuleRatio[id];
            uint sendingCount = randomSendingRuleSendingCount[id];
            _sendingDestinationDetermination(sendingCount, ratio, constantTotalSupply, rand);
        }

        // difinitely send
        for (uint definitelySendingRuleId = 1; definitelySendingRuleId < definitelySendingRuleIds.length; definitelySendingRuleId++) {
            address destinationAddress = definitelySendingRuleAddress[definitelySendingRuleId];
            if (destinationAddress == address(0)) { continue; }
            uint ratio = definitelySendingRuleRatio[definitelySendingRuleId];

            erc20.transfer(destinationAddress, constantTotalSupply / ratio);
        }

        closeTimestamp += cycle;
        delete participants; // reset participants
    }

    /**
    * @notice Determination of winners and transfer of ERC20 tokens
    * @param _sendingCount Number of times to send
    * @param _ratio Ratio to be sent
    * @param _constantTotalSupply Constant value of the amount collected
    * @param _rand random number for using determination of winners
    */
    function _sendingDestinationDetermination(uint _sendingCount, uint _ratio, uint _constantTotalSupply, uint _rand) private {
        for (uint count = 0; count < _sendingCount; count++) {
            uint randWithTotal = getRandWithCurrentTotal(_rand);
            address destinationAddress = _getDestinationAddress(randWithTotal); // 抽選の確定
            uint dividendAmount = _constantTotalSupply / _ratio;
            erc20.transfer(destinationAddress, dividendAmount);
        }
    }

    function _getDestinationAddress(uint randWithTotal) private view returns(address) {
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

    function randomSendingRuleRatioById(uint _id) public view returns (uint) {
        return randomSendingRuleRatio[_id];
    }

    function randomSendingRuleSendingCountById(uint _id) public view returns (uint) {
        return randomSendingRuleSendingCount[_id];
    }

    function createRandomSendingRule(uint _ratio, uint _sendingCount) public onlyOwner canChangeRuleByTime canSetRandomSendingRules(_ratio, _sendingCount) {
        uint id = randomSendingRuleIds.length + 1;
        randomSendingRuleIds.push(id);
        randomSendingRuleRatio[id] = _ratio;
        randomSendingRuleSendingCount[id] = _sendingCount;
    }

    function deleteRandomSendintRule(uint _id) public onlyOwner canChangeRuleByTime {
        uint index = _id - 1;
        require(randomSendingRuleIds[index] != 0, "deleteRandomSendintRule: randomSendingRuleId not found");
        delete randomSendingRuleIds[index];
        delete randomSendingRuleRatio[_id];
        delete randomSendingRuleSendingCount[_id];
    }

    function definitelySendingRuleRatioById(uint _id) public view returns (uint) {
        return definitelySendingRuleRatio[_id];
    }

    function definitelySendingRuleAddressById(uint _id) public view returns (address) {
        return definitelySendingRuleAddress[_id];
    }

    function createDefinitelySendingRule(
        uint _ratio,
        address _destinationAddress
    )
    public onlyOwner canChangeRuleByTime canCreateDefinitelySendingRules(_ratio) {
        uint id = definitelySendingRuleIds.length + 1;
        definitelySendingRuleIds.push(id);
        definitelySendingRuleAddress[id] = _destinationAddress;
        definitelySendingRuleRatio[id] = _ratio;
    }

    function deleteDefinitelySendingRule(uint _id) public onlyOwner canChangeRuleByTime {
        uint index = _id - 1;
        require(definitelySendingRuleIds[index] != 0, "deleteDefinitelySendingRule: definitelySendingRuleId not found");
        delete definitelySendingRuleIds[index];
        delete definitelySendingRuleAddress[_id];
        delete definitelySendingRuleRatio[_id];
    }

    function getDefinitelySendingRuleIds() public view returns (uint[] memory) {
        return definitelySendingRuleIds;
    }
    
    modifier canSetRandomSendingRules(uint _ratio, uint _sendingCount) {
        uint totalAmount = currentRandomSendingTotal() + (10 ** 18 / _ratio) * _sendingCount;
        require(
            totalAmount < 10 ** 18, 
            "TimedRandomSendContract: Only less than 100%"
        );
        _;
    }

    modifier canCreateDefinitelySendingRules(uint _ratio) {
        uint totalAmount = currentRandomSendingTotal() + (10 ** 18 / _ratio);
        require(
            totalAmount < 10 ** 18, 
            "TimedRandomSendContract: Only less than 100%"
        );
        _;
    }

    modifier canChangeRuleByTime() {
        uint elapsedTime = closeTimestamp - block.timestamp;
        require(
            block.timestamp < ((closeTimestamp - cycle) + (elapsedTime / 10)),
            "TimedRandomSendContract: Rule changes can be made up to one-tenth of the end time."
        );
        _;
    }

    function currentRandomSendingTotal() public view returns(uint) {
        uint totalAmount = 0;
        for (uint i = 0; i < randomSendingRuleIds.length; i++) {
            uint id = randomSendingRuleIds[i];
            if (id == 0) { continue; }

            uint ratio = randomSendingRuleRatio[id];
            uint sendingCount = randomSendingRuleSendingCount[id];
            totalAmount += (10 ** 18 / ratio) * sendingCount;
        }
        return totalAmount;
    }

    function getRandWithCurrentTotal(uint rand) public view returns (uint) {
        return getNumber(totalSupply() + rand);
    }

    function getRand() public returns (uint rand) {
        // production
        // bytes32 requestId = getRandomNumber();
        // requestMap[requestId] = eventCounts;
        // return randomMap[eventCounts];

        // dev
        return getNumber(block.timestamp);
    }

    function getNumber(uint number) public view returns (uint) {
        return uint(keccak256(abi.encode(number))) % totalSupply();
    }

    function getNumberFromAddress(address account) public pure returns (uint) {
        return uint256(keccak256(abi.encodePacked(account)));
    }

    function totalSupply() public view returns(uint) {
        return erc20.balanceOf(address(this));
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

     /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint value);


     /** 
     * Requests randomness 
     */
    function getRandomNumber() private returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        // constrain random number between 1-10
        uint256 modRandom = randomResult;
        // get eventCounts that created the request
        uint256 thisEventCounts = requestMap[requestId];
        // store random result in token image map
        randomMap[thisEventCounts] = modRandom;
    }
}

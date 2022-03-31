pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";


/**
 * @title TimedRandomSendContract
 * @author Peter Takahashi(CEO of CryptoLottery)
 * @notice This smart contract collects ERC20 tokens in a single wallet and
           uses chainlink VRF to transfer the ERC20 tokens to the winners.
 */

contract TimedRandomSendContract is VRFConsumerBase, Ownable {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint public cycle;
    uint public closeTimestamp;
    uint public eventCounts = 1;
    address[] public participants;
    IERC20 public erc20; // erc20 token used for lottery
    mapping(address => uint256) public balanceOf; // maps a wallet address to a wallet balance

    uint immutable minimumBuyLotteryPrice = 10 ** 16; // 0.001
    uint immutable baseTokenAmount = 10 ** 18;

    /// RandomSendingRule
    struct RandomSendingRule {
        uint id;
        uint ratio;
        uint sendingCount;
    }
    uint[] public randomSendingRuleIds;
    mapping(uint => uint) private randomSendingRuleRatio;
    mapping(uint => uint) private randomSendingRuleSendingCount;

    /// definitelySendingRule
    struct DefinitelySendingRule {
        uint id;
        uint ratio;
        address sendingAddress;
    }
    uint[] public definitelySendingRuleIds;
    mapping(uint => address) private definitelySendingRuleAddress;
    mapping(uint => uint) private definitelySendingRuleRatio;
    

    // Chainlink VRF Variables
    bytes32 public keyHash;
    uint256 public fee = 10 ** 17; // 0.1 link
    uint256 public randomResult;

    // Chainlink Value Maps
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
        require(minimumBuyLotteryPrice <= _amount, "TimedRandomSendContract: _amount must be set above the minimum price");
        require(erc20.balanceOf(msg.sender) >= _amount, "TimedRandomSendContract: Not enough erc20 tokens.");

        // Save how much you have purchased
        balanceOf[msg.sender] += _amount;

        // lottery purchaser add participants
        participants.push(msg.sender);

        // Lock the Lottery in the contract
        erc20.transferFrom(msg.sender, address(this), _amount);
    }
    
    /**
    * @notice random send ERC20 token to lottery participants
    * @dev require there is randomMap[thisEventCounts] value and after close time
    */
    function randSend() public onlyAfterCloseTimestamp onlyHaveThisEventRandomNumber {
        uint constantTotalSupply = totalSupply();

        // random send
        for (uint index = 0; index < randomSendingRuleIds.length; index++) {
            uint id = randomSendingRuleIds[index];
            if (id == 0) { continue; }
            uint ratio = randomSendingRuleRatio[id];
            uint sendingCount = randomSendingRuleSendingCount[id];
            _sendingDestinationDetermination(sendingCount, ratio, constantTotalSupply);
        }

        // difinitely send
        for (uint definitelySendingRuleId = 1; definitelySendingRuleId < definitelySendingRuleIds.length; definitelySendingRuleId++) {
            address destinationAddress = definitelySendingRuleAddress[definitelySendingRuleId];
            if (destinationAddress == address(0)) { continue; }
            uint ratio = definitelySendingRuleRatio[definitelySendingRuleId];

            erc20.transfer(destinationAddress, constantTotalSupply.div(ratio));
        }

        eventCounts += 1;
        closeTimestamp += cycle;
        delete participants; // reset participants
    }

    /**
    * @notice Determination of winners and transfer of ERC20 tokens
    * @param _sendingCount Number of times to send
    * @param _ratio Ratio to be sent
    * @param _constantTotalSupply Constant value of the amount collected
    */
    function _sendingDestinationDetermination(uint _sendingCount, uint _ratio, uint _constantTotalSupply) private {
        for (uint count = 0; count < _sendingCount; count++) {
            uint randWithTotalSupply = getRandWithTotalSupply();
            address winnerAddress = _getWinnerAddress(randWithTotalSupply);
            uint dividendAmount = _constantTotalSupply.div(_ratio);

            // send erc20 to winner
            erc20.transfer(winnerAddress, dividendAmount);
        }
    }

    /**
    * @notice get winner address
    * @param _randWithTotalSupply random number
    */
    function _getWinnerAddress(uint _randWithTotalSupply) private view returns(address) {
        uint number = 0;
        address winnerAddress;
        for (uint count = 0; count < participants.length; count++) {
            // TODO: この辺の当選ロジックは修正する
            if (number < _randWithTotalSupply && _randWithTotalSupply > number + balanceOf[participants[count]]) {
                winnerAddress = participants[count];
                break;
            }
            number += balanceOf[participants[count]];
        }
        // Return the winner's address.
        return winnerAddress;
    }

    /**
    * @notice get random sending rule ratio by id
    * @param _id random sending rule id
    */
    function randomSendingRuleRatioById(uint _id) public view returns (uint) {
        return randomSendingRuleRatio[_id];
    }

    /**
    * @notice get random sending rule count by id
    * @param _id random sending rule id
    */
    function randomSendingRuleSendingCountById(uint _id) public view returns (uint) {
        return randomSendingRuleSendingCount[_id];
    }

    /**
    * @notice create random sending rule
    * @param _ratio random sending rule ratio
    * @param _sendingCount random sending rule sending count
    */
    function createRandomSendingRule(uint _ratio, uint _sendingCount) public onlyOwner canChangeRuleByTime canCreateRandomSendingRules(_ratio, _sendingCount) {
        uint id = randomSendingRuleIds.length + 1;
        randomSendingRuleIds.push(id);
        randomSendingRuleRatio[id] = _ratio;
        randomSendingRuleSendingCount[id] = _sendingCount;
    }

    /**
    * @notice delete random sending rule
    * @param _id random sending rule id
    */
    function deleteRandomSendintRule(uint _id) public onlyOwner canChangeRuleByTime {
        uint index = _id - 1;
        require(randomSendingRuleIds[index] != 0, "deleteRandomSendintRule: randomSendingRuleId not found");
        delete randomSendingRuleIds[index];
        delete randomSendingRuleRatio[_id];
        delete randomSendingRuleSendingCount[_id];
    }

    /**
    * @notice get definitely sending rule ratio by id
    * @param _id definitely sending rule id
    */
    function definitelySendingRuleRatioById(uint _id) public view returns (uint) {
        return definitelySendingRuleRatio[_id];
    }

    /**
    * @notice get definitely sending rule address by id
    * @param _id definitely sending rule id
    */
    function definitelySendingRuleAddressById(uint _id) public view returns (address) {
        return definitelySendingRuleAddress[_id];
    }

    /**
    * @notice create definitely sending rule
    * @param _ratio definitely sending rule ratio
    * @param _destinationAddress destination address
    */
    function createDefinitelySendingRule(
        uint _ratio,
        address _destinationAddress
    ) public onlyOwner canChangeRuleByTime canCreateDefinitelySendingRules(_ratio) {
        uint id = definitelySendingRuleIds.length + 1;
        definitelySendingRuleIds.push(id);
        definitelySendingRuleAddress[id] = _destinationAddress;
        definitelySendingRuleRatio[id] = _ratio;
    }

    /**
    * @notice delete definitely sending rule
    * @param _id definitely sending rule id
    */
    function deleteDefinitelySendingRule(uint _id) public onlyOwner canChangeRuleByTime {
        uint index = _id - 1;
        require(definitelySendingRuleIds[index] != 0, "deleteDefinitelySendingRule: definitelySendingRuleId not found");
        delete definitelySendingRuleIds[index];
        delete definitelySendingRuleAddress[_id];
        delete definitelySendingRuleRatio[_id];
    }

    /**
    * @notice get definitely sending rule ids
    */
    function getDefinitelySendingRuleIds() public view returns (uint[] memory) {
        return definitelySendingRuleIds;
    }
    
    /**
    * @notice Can it create a CreateRandomSendingRules?
    * @param _ratio RandomSendingRule ratio
    * @param _sendingCount RandomSendingRule sending count
    */
    modifier canCreateRandomSendingRules(uint _ratio, uint _sendingCount) {
        uint totalAmount = currentRandomSendingRatioTotal() + baseTokenAmount.div(_ratio) * _sendingCount;
        require(
            totalAmount < baseTokenAmount, 
            "TimedRandomSendContract: Only less than 100%"
        );
        _;
    }

    /**
    * @notice Can it create a DefinitelySendingRule?
    * @param _ratio Definitely Sending Rule ratio
    */
    modifier canCreateDefinitelySendingRules(uint _ratio) {
        uint totalAmount = currentRandomSendingRatioTotal() + baseTokenAmount.div(_ratio);
        require(
            totalAmount < baseTokenAmount, 
            "TimedRandomSendContract: Only less than 100%"
        );
        _;
    }

    /**
    * @notice Is it possible time to change the lottery rules?
    */
    modifier canChangeRuleByTime() {
        uint elapsedTime = closeTimestamp - block.timestamp;
        require(
            block.timestamp < ((closeTimestamp - cycle) + (elapsedTime.div(10))),
            "TimedRandomSendContract: Rule changes can be made up to one-tenth of the end time."
        );
        _;
    }

    modifier onlyAfterCloseTimestamp() {
        require(closeTimestamp <= block.timestamp, "TimedRandomSendContract: The time has not yet reached the closing time.");
        _;
    }

    /**
    * @notice require have randomMap[thisEventCounts] value
    */
    modifier onlyHaveThisEventRandomNumber() {
        require(thisEventRandomNumber() != 0, "TimedRandomSendContract: don't have this event random number");
        _;
    }

    /**
    * @notice require don't have randomMap[thisEventCounts] value
    */
    modifier onlyNotHaveThisEventRandomNumber() {
        require(thisEventRandomNumber() == 0, "TimedRandomSendContract: have this event random number");
        _;
    }

    /**
    * @notice Current Ratio of Random Sending Rule
    * @dev Need to get the current lottery return rate because if the lottery return rate exceeds 100%,
           the lottery will no longer function.
    */
    function currentRandomSendingRatioTotal() public view returns(uint) {
        uint totalAmount = 0;
        for (uint i = 0; i < randomSendingRuleIds.length; i++) {
            uint id = randomSendingRuleIds[i];
            if (id == 0) { continue; }

            uint ratio = randomSendingRuleRatio[id];
            uint sendingCount = randomSendingRuleSendingCount[id];

            totalAmount += (baseTokenAmount.div(ratio)) * sendingCount;
        }
        return totalAmount;
    }

    function getRandomNumber() public onlyNotHaveThisEventRandomNumber onlyAfterCloseTimestamp returns (uint rand) {
        // production
        // bytes32 requestId = getRandomNumberFromChainLink();
        // requestMap[requestId] = eventCounts;
        // return randomMap[eventCounts];

        // dev
        randomMap[eventCounts] = getNumber(block.timestamp);
        return getNumber(block.timestamp);
    }

    /**
    * @notice get number with totalSupply
    */
    function getRandWithTotalSupply() public view returns (uint) {
        return getNumber(totalSupply() + thisEventRandomNumber());
    }

    /**
    * @notice get number
    */
    function getNumber(uint _number) public view returns (uint) {
        return uint(keccak256(abi.encode(_number))) % totalSupply();
    }

    /**
    * @notice ERC20 tokens collected by lottery
    */
    function totalSupply() public view returns(uint) {
        return erc20.balanceOf(address(this));
    }

    /**
    * @notice get this event random number from randomMap
    */
    function thisEventRandomNumber() private view returns(uint) {
        return randomMap[eventCounts];
    }

     /** 
     * @notice Requests randomness from chainlink
     */
    function getRandomNumberFromChainLink() private returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
        randomResult = _randomness;
        // constrain random number between 1-10
        uint256 modRandom = randomResult;
        // get eventCounts that created the request
        uint256 thisEventCounts = requestMap[_requestId];
        // store random result in token image map
        randomMap[thisEventCounts] = modRandom;
    }
}

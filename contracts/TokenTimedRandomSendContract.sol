// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";


contract TokenTimedRandomSendContract is VRFConsumerBase, Ownable {
    using SafeMath for uint256;

    // constant
    string public name;
    string public symbol;
    uint public cycleTimestamp;
    uint public closeTimestamp;
    IERC20 public erc20; // erc20 token used for lottery
    uint public sellerCommission;
    bool public isOnlyOwner;

    // Chainlink VRF Variables
    bytes32 public keyHash;
    uint256 public fee = 0.1 ether; // 0.1 link

    // Chainlink Value Maps
    mapping(uint256 => uint256) public randomMap; // maps a index to a random number
    mapping(bytes32 => uint256) public requestMap; // maps a requestId to a index

    uint public index = 1; // event count

    // ticket config
    mapping(uint => uint) public _ticketPrice;

    // able to buy ticket
    bool public isAccepting;

    // ticket
    mapping(uint => uint) private _ticketLastId;
    mapping(uint => mapping(uint => uint)) private _ticketCount;
    mapping(uint => mapping(uint => uint)) private _ticketLastNumber;
    mapping(uint => mapping(address => uint[])) private _ticketIds;
    mapping(uint => mapping(uint => uint)) private _ticketReceivedAt;

    // participant
    mapping(uint => uint) private _participantCount;
    mapping(uint => mapping(address => bool)) public _isParticipated;

    // RandomSendingRule
    mapping(uint => uint[]) private _randomSendingRuleIds;
    mapping(uint => mapping(uint => uint)) private _randomSendingRuleRatio;
    mapping(uint => mapping(uint => uint)) private _randomSendingRuleSendingCount;
    mapping(uint => uint) public randomSendingRuleRatioTotalAmount;

    /// definitelySendingRule
    mapping(uint => uint[]) private _definitelySendingRuleIds;
    mapping(uint => mapping(uint => address)) private _definitelySendingRuleAddress;
    mapping(uint => mapping(uint => uint)) private _definitelySendingRuleRatio;
    mapping(uint => uint) public definitelySendingRuleRatioTotalAmount;

    uint immutable baseTokenAmount = 10 ** 18;

    constructor(
        string memory _name,
        string memory _symbol,
        uint _cycleTimestamp,
        IERC20 _erc20,
        address _link,
        address _coordinator, 
        bytes32 _keyHash,
        uint _sellerCommission,
        uint __ticketPrice,
        bool _isOnlyOwner)
    VRFConsumerBase(_coordinator, _link)
    {
        name = _name;
        symbol = _symbol;
        cycleTimestamp = _cycleTimestamp;
        closeTimestamp = block.timestamp + _cycleTimestamp;
        erc20 = _erc20;
        sellerCommission = _sellerCommission;
        _ticketPrice[index] = __ticketPrice;
        isOnlyOwner = _isOnlyOwner;
        
        // Chainlink setters
        keyHash = _keyHash;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
        uint256 randomResult = _randomness;
        // constrain random number between 1-10
        uint256 modRandom = randomResult;
        // get index that created the request
        uint256 _index = requestMap[_requestId];
        // store random result in token image map
        randomMap[_index] = modRandom;
    }

    /** 
     * Requests randomness 
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

     /**
    * @notice buy lottery ticket
    * @param __ticketCount Amount of lottery tickets
    * @param seller ticket seller
    * @dev When you buy a lottery ticket, you lock the funds in a smart contract wallet.
    * onlyOwnerWhenIsOnlyOwner オーナーだけがチケットを購入できるようにする or 誰でもチケットを購入できるようにする
    */
    function buyTicket(uint256 __ticketCount, address seller) public payable onlyAccepting onlyOwnerWhenIsOnlyOwner {
        uint tokenAmount = __ticketCount * _ticketPrice[index];
        require(erc20.balanceOf(msg.sender) >= tokenAmount, "TokenTimedRandomSendContract: Not enough erc20 tokens.");

        // ticket
        _ticketLastId[index]++;
        _ticketCount[index][_ticketLastId[index]] = __ticketCount;
        _ticketLastNumber[index][_ticketLastId[index]] = _ticketLastNumber[index][_ticketLastId[index] - 1] + __ticketCount;

        _ticketIds[index][msg.sender].push(_ticketLastId[index]);
        _ticketReceivedAt[index][_ticketLastId[index]] = block.timestamp;

        addParticipantCount(msg.sender);

        // Lock the Lottery in the contract
        erc20.transferFrom(msg.sender, address(this), tokenAmount);

        erc20.transfer(seller, tokenAmount.div(sellerCommission));
    }

    function sendTicket(uint ticketIdsIndex, address to) public onlyAccepting onlyOwner {
        uint ticketId = ticketIdFromTicketIds(ticketIdsIndex);

        // remove
        _ticketIds[index][msg.sender][ticketIdsIndex] = _ticketIds[index][msg.sender][_ticketIds[index][msg.sender].length - 1];
        _ticketIds[index][msg.sender].pop();

        // add
        _ticketIds[index][to].push(ticketId);
        addParticipantCount(to);
    }

    /**
    * @notice add participant count
    */
    function addParticipantCount(address user) internal {
        if (!_isParticipated[index][user]) {
            // lottery purchaser add participants
            _participantCount[index] += 1;
        }

        _isParticipated[index][user] = true;
    }

       /**
    * @notice create random sending rule
    * @param _ratio random sending rule ratio
    * @param _sendingCount random sending rule sending count
    */
    function createRandomSendingRule(uint _ratio, uint _sendingCount) public onlyAccepting onlyOwner canCreateSendingRule(_ratio, _sendingCount) {
        uint id = _randomSendingRuleIds[index].length + 1;
        _randomSendingRuleIds[index].push(id);
        _randomSendingRuleRatio[index][id] = _ratio;
        _randomSendingRuleSendingCount[index][id] = _sendingCount;

        randomSendingRuleRatioTotalAmount[index] = randomSendingRuleRatioTotalAmount[index] + randomSendingRatioAmount(_ratio, _sendingCount);
    }

    /**
    * @notice delete random sending rule
    * @param randomSendingRuleIndex random sending rule index
    */
    function deleteRandomSendingRule(uint randomSendingRuleIndex) public onlyAccepting onlyOwner {
        uint id = _randomSendingRuleIds[index][randomSendingRuleIndex];
        require(_randomSendingRuleIds[index][randomSendingRuleIndex] != 0, "deleteRandomSendingRule: randomSendingRuleId not found");
        randomSendingRuleRatioTotalAmount[index] = randomSendingRuleRatioTotalAmount[index] - randomSendingRatioAmount(_randomSendingRuleRatio[index][id], _randomSendingRuleSendingCount[index][id]);
        _randomSendingRuleIds[index][randomSendingRuleIndex] = _randomSendingRuleIds[index][_randomSendingRuleIds[index].length - 1];
        _randomSendingRuleIds[index].pop();
        delete _randomSendingRuleRatio[index][id];
        delete _randomSendingRuleSendingCount[index][id];
    }

    /**
    * @notice create definitely sending rule
    * @param _ratio definitely sending rule ratio
    * @param _destinationAddress destination address
    */
    // TODO: チケット購入の受付が開始されたらルールは変更できないようにする
    function createDefinitelySendingRule(
        uint _ratio,
        address _destinationAddress
    ) public onlyAccepting onlyOwner canCreateSendingRule(_ratio, 1) {
        uint id = lastDefinitelySendingRuleIds() + 1;
        _definitelySendingRuleIds[index].push(id);
        _definitelySendingRuleAddress[index][id] = _destinationAddress;
        _definitelySendingRuleRatio[index][id] = _ratio;

        definitelySendingRuleRatioTotalAmount[index] = definitelySendingRuleRatioTotalAmount[index] + ratioAmount(_ratio);
    }

    /**
    * @notice delete definitely sending rule
    * @param definitelySendingRuleIndex definitely sending rule index
    */
    function deleteDefinitelySendingRule(uint definitelySendingRuleIndex) public onlyAccepting onlyOwner {
        uint id = _definitelySendingRuleIds[index][definitelySendingRuleIndex];
        require(_definitelySendingRuleIds[index][definitelySendingRuleIndex] != 0, "deleteDefinitelySendingRule: definitelySendingRuleId not found");
        _definitelySendingRuleIds[index][definitelySendingRuleIndex] = _definitelySendingRuleIds[index][_definitelySendingRuleIds[index].length - 1];
        _definitelySendingRuleIds[index].pop();
        definitelySendingRuleRatioTotalAmount[index] = definitelySendingRuleRatioTotalAmount[index] - ratioAmount(_definitelySendingRuleRatio[index][id]);
        delete _definitelySendingRuleAddress[index][id];
        delete _definitelySendingRuleRatio[index][id];
    }

    modifier onlyOwnerWhenIsOnlyOwner {
        if (isOnlyOwner) {
            require(owner() == _msgSender(), "Ownable: caller is not the owner");
        }
        _;
    }

    modifier onlyAfterCloseTimestamp() {
        require(closeTimestamp <= block.timestamp, "TimedRandomSendContract: The time has not yet reached the closing time.");
        _;
    }

    modifier onlyAccepting() {
        require(isAccepting, "TimedRandomSendContract: only accept");
        _;
    }

    /**
    * @notice Can it create a sending rule
    * @param _ratio Sending Rule ratio
    * @param _sendingCount SendingRule sending count
    */
    modifier canCreateSendingRule(uint _ratio, uint _sendingCount) {
        uint totalAmount = randomSendingRuleRatioTotalAmount[index] + definitelySendingRuleRatioTotalAmount[index] + (ratioAmount(_ratio) * _sendingCount);
        require(
            totalAmount < baseTokenAmount, 
            "TimedRandomSendContract: Only less than 100%"
        );
        _;
    }

    function ticketIdFromTicketIds(uint _ticketIdsIndex) internal view returns(uint) {
        return _ticketIds[index][msg.sender][_ticketIdsIndex];
    }

    function ticketPrice(uint _index) public view returns(uint) {
        return _ticketPrice[_index];
    }

    function ticketLastId(uint _index) public view returns(uint) {
        return _ticketLastId[_index];
    }

    function ticketCount(uint _index, uint ticketId) public view returns(uint) {
        return _ticketCount[_index][ticketId];
    }

    function ticketLastNumber(uint _index, uint ticketId) public view returns(uint) {
        return _ticketLastNumber[_index][ticketId];
    }

    function ticketReceivedAt(uint _index, uint ticketId) public view returns(uint) {
        return _ticketReceivedAt[_index][ticketId];
    }

    function participantCount(uint _index) public view returns(uint) {
        return _participantCount[_index];
    }

    function isParticipated(uint _index, address user) public view returns(bool) {
        return _isParticipated[_index][user];
    }

    function ticketIds(uint _index, address user) public view returns(uint[] memory) {
        return _ticketIds[_index][user];
    }

    function randomSendingRuleIds(uint _index) public view returns(uint[] memory) {
        return _randomSendingRuleIds[_index];
    }

    function definitelySendingRuleIds(uint _index) public view returns(uint[] memory) {
        return _definitelySendingRuleIds[_index];
    }

    function lastDefinitelySendingRuleIds() internal view returns(uint) {
        if (_definitelySendingRuleIds[index].length == 0) {
            return 0;
        }
        return _definitelySendingRuleIds[index][_definitelySendingRuleIds[index].length - 1];
    }

    /**
    * @notice ERC20 tokens collected by this contract
    */
    function totalSupply() public view returns(uint) {
        return erc20.balanceOf(address(this));
    }

    function randomSendingRatioAmount(uint _ratio, uint _sendingCount) internal pure returns(uint) {
        return ratioAmount(_ratio) * _sendingCount;
    }

    function ratioAmount(uint _ratio) internal pure returns(uint) {
        return baseTokenAmount / _ratio;
    }

    function startAccepting() public onlyOwner {
        // Once this is changed to true, it cannot be changed to false until close.
        isAccepting = true;
    }
}
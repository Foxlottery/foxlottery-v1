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
    bool public isOnlyOwner;

    // Chainlink VRF Variables
    bytes32 public keyHash;
    uint256 public fee = 0.1 ether; // 0.1 link

    // Chainlink Value Maps
    mapping(uint256 => uint256) public randomMap; // maps a eventCount to a random number
    mapping(bytes32 => uint256) public requestMap; // maps a requestId to a eventCount

    uint public index = 1; // event count

    // ticket config
    mapping(uint => uint) public _ticketPrice;

    // ticket
    mapping(uint => uint) public _ticketLastId;
    mapping(uint => mapping(uint => uint)) private _ticketCount;
    mapping(uint => mapping(uint => uint)) private _ticketLastNumber;
    mapping(uint => mapping(address => uint[])) private _ticketIds;
    mapping(uint => mapping(uint => uint)) private _ticketReceivedAt;

    // participant
    mapping(uint => uint) private _participantCount;
    mapping(uint => mapping(address => bool)) public _isParticipated;

    constructor(
        string memory _name,
        string memory _symbol,
        uint _cycleTimestamp,
        IERC20 _erc20,
        address _link,
        address _coordinator, 
        bytes32 _keyHash,
        uint __ticketPrice,
        bool _isOnlyOwner)
    VRFConsumerBase(_coordinator, _link)
    {
        name = _name;
        symbol = _symbol;
        cycleTimestamp = _cycleTimestamp;
        closeTimestamp = block.timestamp + _cycleTimestamp;
        erc20 = _erc20;
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
        // get eventCount that created the request
        uint256 thisEventCounts = requestMap[_requestId];
        // store random result in token image map
        randomMap[thisEventCounts] = modRandom;
    }

     /**
    * @notice buy lottery ticket
    * @param __ticketCount Amount of lottery tickets
    * @dev When you buy a lottery ticket, you lock the funds in a smart contract wallet.
    * onlyOwnerable オーナーだけがチケットを購入できるようにする or 誰でもチケットを購入できるようにする
    */
    function buyTicket(uint256 __ticketCount) public payable onlyBeforeCloseTimestamp onlyOwnerable {
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
    }

    function sendTicket(uint ticketIdsIndex, address to) public onlyOwner {
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

    function ticketIds(uint _index, address user) public view returns(uint[] memory) {
        return _ticketIds[_index][user];
    }

    /**
    * @notice ERC20 tokens collected by this contract
    */
    function totalSupply() public view returns(uint) {
        return erc20.balanceOf(address(this));
    }

    modifier onlyBeforeCloseTimestamp() {
        require(closeTimestamp >= block.timestamp, "TokenTimedRandomSendContract: This operation can be performed only before CloseTime.");
        _;
    }

    modifier onlyOwnerable {
        if (isOnlyOwner) {
            require(owner() == _msgSender(), "Ownable: caller is not the owner");
        }
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
}
pragma solidity ^0.8.14;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";


contract TokenTimedRandomSendContract is VRFConsumerBase, Ownable {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint public cycleTimestamp;
    uint public closeTimestamp;
    IERC20 public erc20; // erc20 token used for lottery
    uint public ticketPrice;
    uint public ticketLastId = 0;
    bool public isOnlyOwner;

    // ticket
    mapping(uint => uint) public ticketCount;
    mapping(uint => uint) public ticketLastNumber;
    mapping(address => uint[]) private ticketIds;
    mapping(uint => address) public ticketOwner;
    mapping(address => mapping(uint => bool)) public ticketIdMap;
    mapping(uint => uint) public ticketBoughtAt;

    // participant
    uint public participantCount = 0;
    mapping(address => bool) public isParticipated;

    // Chainlink VRF Variables
    bytes32 public keyHash;
    uint256 public fee = 0.1 ether; // 0.1 link

    // Chainlink Value Maps
    mapping(uint256 => uint256) public randomMap; // maps a eventCount to a random number
    mapping(bytes32 => uint256) public requestMap; // maps a requestId to a eventCount

    constructor(
        string memory _name,
        string memory _symbol,
        uint _cycleTimestamp,
        IERC20 _erc20,
        address _link,
        address _coordinator, 
        bytes32 _keyHash,
        uint _ticketPrice,
        bool _isOnlyOwner)
    VRFConsumerBase(_coordinator, _link)
    {
        name = _name;
        symbol = _symbol;
        cycleTimestamp = _cycleTimestamp;
        closeTimestamp = block.timestamp + _cycleTimestamp;
        erc20 = _erc20;
        ticketPrice = _ticketPrice;
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
    * @param _ticketCount Amount of lottery tickets
    * @dev When you buy a lottery ticket, you lock the funds in a smart contract wallet.
    * onlyOwnerable オーナーだけがチケットを購入できるようにする or 誰でもチケットを購入できるようにする
    */
    function buyTicket(uint256 _ticketCount) public payable onlyBeforeCloseTimestamp onlyOwnerable {
        uint tokenAmount = _ticketCount * ticketPrice;
        require(erc20.balanceOf(msg.sender) >= tokenAmount, "TokenTimedRandomSendContract: Not enough erc20 tokens.");

        // ticket
        ticketLastId++;
        ticketCount[ticketLastId] = _ticketCount;
        ticketLastNumber[ticketLastId] = ticketLastNumber[ticketLastId - 1] + _ticketCount;

        ticketIds[msg.sender].push(ticketLastId);
        ticketOwner[ticketLastId] = msg.sender;
        ticketBoughtAt[ticketLastId] = block.timestamp;

        addParticipantCount();

        // Lock the Lottery in the contract
        erc20.transferFrom(msg.sender, address(this), tokenAmount);
    }

    function sendTicket(uint ticketIdsIndex, address to) public onlyOwner {
        uint ticketId = getTicketIdFromTicketIds(ticketIdsIndex);
        console.log(ticketId);
        // // remove
        // ticketIds[msg.sender][ticketIdsIndex] = ticketIds[msg.sender][ticketIds[msg.sender].length - 1];
        // ticketIds[msg.sender].pop();
        // delete ticketOwner[ticketId];

        // // add
        // ticketIds[to].push(ticketId);
        // ticketOwner[ticketId] = to;
    }

    /**
    * @notice add participant count
    */
    function addParticipantCount() internal {
        if (!isParticipated[msg.sender]) {
            // lottery purchaser add participants
            participantCount += 1;
        }

        isParticipated[msg.sender] = true;
    }

    function getTicketIds(address user) public view returns(uint[] memory) {
        return ticketIds[user];
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

    modifier hasTicket(uint ticketIdsIndex) {
        uint ticketId = getTicketIdFromTicketIds(ticketIdsIndex);
        require(ticketOwner[ticketLastId] == msg.sender, "TokenTimedRandomSendContract: require have ticket");
        _;
    }

    function getTicketIdFromTicketIds(uint ticketIdsIndex) internal view returns(uint) {
        console.log(ticketIds[msg.sender].length);
        return ticketIds[msg.sender][ticketIdsIndex];
    }
}
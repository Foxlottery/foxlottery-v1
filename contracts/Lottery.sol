// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// chainlink
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Lottery
 * @author Seiya Takahashi (github: https://github.com/PeterTakahashi)
 * @notice The owner can easily create a lottery by setting the closing time, the rules of the drawing, the commission to the seller, and the name.
 */
contract Lottery is VRFConsumerBaseV2, Ownable {
    using SafeMath for uint256;
    enum Status { 
        ACCEPTING,
        RANDOM_VALUE_GETTING,
        TOKEN_SENDING,
        DONE,
        RULE_SETTING
    }
    Status public status = Status.RULE_SETTING;

    enum TokenSengingStatus {
        SEND_TO_SELLER,
        RANDOM_SEND,
        DEFINITELY_SEND
    }
    TokenSengingStatus public tokenSengingStatus;
    uint private constant MAX_COUNT = 20;
    uint private constant MAX_SENDING_COUNT = 1000;

    // constant
    string public name;
    string public symbol;
    uint public cycle; // Lottery time cycle
    uint public closeTimestamp;
    IERC20 public erc20; // erc20 token used for lottery
    bool public isOnlyOwner;
    uint public immutable baseTokenAmount = 10 ** 18;

    // sellerCommission
    uint public sellerCommissionRatio;
    uint public sellerCommissionRatioTotalAmount;
    // RandomSendingRule
    uint public lastRandomSendingRuleId;
    mapping(uint => uint) public randomSendingRuleRatio;
    mapping(uint => uint) public randomSendingRuleSendingCount;
    uint public randomSendingRuleRatioTotalAmount;
    uint public currentRandomSendingRuleId;
    uint public currentRandomSendingRuleSendingCount;
    /// definitelySendingRule
    uint public lastDefinitelySendingRuleId;
    mapping(uint => address) public definitelySendingRuleAddress;
    mapping(uint => uint) public definitelySendingRuleRatio;
    uint public definitelySendingRuleRatioTotalAmount;
    uint public currentDefinitelySendingId;
    mapping(address => bool) public isDestinationAddress;

    // totalSupplyB
    mapping(uint => uint) public totalSupplyByIndex;

    // event count
    uint public index = 1;

    // chainlink vrf
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 public immutable subscriptionId;
    // chainlink vrf coordinator
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address public vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 public keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    // ticket config
    uint public ticketPrice;

    // ticket
    mapping(uint => uint) private _ticketLastId;
    mapping(uint => mapping(uint => uint)) private _ticketCount;
    mapping(uint => mapping(uint => uint)) private _ticketLastNumber;
    mapping(uint => mapping(address => uint[])) private _ticketIds;
    mapping(uint => mapping(uint => address)) private _ticketHolder;
    mapping(uint => mapping(uint => uint)) private _ticketReceivedAt;

    // participant
    mapping(uint => uint) private _participantCount;
    mapping(uint => mapping(address => bool)) private _isParticipated;

    // seller
    uint public sendToSellerIndex;
    mapping(uint => address[]) public _sellers;
    mapping(uint => mapping(address => bool)) private _isSeller;
    mapping(uint => mapping(address => uint)) private _tokenAmountToSeller;

    // getted random value by chainlink vrf
    mapping(uint => uint) public randomValue;

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory _randomWords
    ) internal override {
        randomValue[index] = _randomWords[0];
        statusToTokenSending();
    }

    function requestRandomWords() private onlyOwner {
        // Will revert if subscription is not set and funded.
        COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _erc20,
        uint _ticketPrice,
        bool _isOnlyOwner,
        uint _cycle,
        uint _closeTimestamp,
        uint64 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(vrfCoordinator)
    {
        require(_cycle != 0 && (_cycle % 1 hours) == 0);
        require((_closeTimestamp % 1 hours) == 0);
        require((_closeTimestamp > block.timestamp + _cycle));
        name = _name;
        symbol = _symbol;
        erc20 = _erc20;
        ticketPrice = _ticketPrice;
        isOnlyOwner = _isOnlyOwner;
        cycle = _cycle;
        closeTimestamp = _closeTimestamp;

        // chainlink
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = _subscriptionId;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
    }

     /**
    * @notice buy lottery ticket
    * @param __ticketCount Amount of lottery tickets
    * @param seller ticket seller
    * @dev When you buy a lottery ticket, you lock the funds in a smart contract wallet.
    */
    function buyTicket(uint256 __ticketCount, address seller) public payable onlyByStatus(Status.ACCEPTING) onlyOwnerWhenIsOnlyOwner requireUnberMaxCount(_ticketIds[index][msg.sender].length) {
        uint tokenAmount = __ticketCount * ticketPrice;
        require(erc20.balanceOf(msg.sender) >= tokenAmount, "Not enough erc20 tokens.");

        // ticket
        _ticketLastId[index]++;
        _ticketCount[index][_ticketLastId[index]] = __ticketCount;
        _ticketLastNumber[index][_ticketLastId[index]] = _ticketLastNumber[index][_ticketLastId[index] - 1] + __ticketCount;

        _ticketIds[index][msg.sender].push(_ticketLastId[index]);
        _ticketReceivedAt[index][_ticketLastId[index]] = block.timestamp;

        _ticketHolder[index][_ticketLastId[index]] = msg.sender;

        addParticipantCount(msg.sender);

        // Lock the Lottery in the contract
        erc20.transferFrom(msg.sender, address(this), tokenAmount);

        if (!_isSeller[index][seller]) {
            _isSeller[index][seller] = true;
            _sellers[index].push(seller);
        }
        if (sellerCommissionRatio > 0) {
          _tokenAmountToSeller[index][seller] = _tokenAmountToSeller[index][seller] + tokenAmount.div(sellerCommissionRatio);
        }
    }

    function sendTicket(uint ticketIdsIndex, address to) public onlyByStatus(Status.ACCEPTING) onlyOwner requireUnberMaxCount(_ticketIds[index][to].length) {
        uint ticketId = ticketIdByTicketIds(ticketIdsIndex);

        // remove
        _ticketIds[index][msg.sender][ticketIdsIndex] = _ticketIds[index][msg.sender][_ticketIds[index][msg.sender].length - 1];
        _ticketIds[index][msg.sender].pop();

        // add
        _ticketIds[index][to].push(ticketId);
        _ticketHolder[index][ticketId] = to;
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
    function createRandomSendingRule(uint _ratio, uint _sendingCount) public
        onlyByStatus(Status.RULE_SETTING)
        onlyOwner
        requireUnberMaxCount(lastRandomSendingRuleId)
        noZero(_ratio)
        noZero(_sendingCount)
        canCreateSendingRule(_ratio, _sendingCount)
        requireUnderMaxSendingCount(_sendingCount)
        requireGreaterThanLastRandomSendingRuleRatio(_ratio)
    {
        lastRandomSendingRuleId++;
        
        randomSendingRuleRatio[lastRandomSendingRuleId] = _ratio;
        randomSendingRuleSendingCount[lastRandomSendingRuleId] = _sendingCount;

        randomSendingRuleRatioTotalAmount = randomSendingRuleRatioTotalAmount + randomSendingRatioAmount(_ratio, _sendingCount);
    }

    /**
    * @notice create definitely sending rule
    * @param _ratio definitely sending rule ratio
    * @param _destinationAddress destination address
    */
    function createDefinitelySendingRule(
        uint _ratio,
        address _destinationAddress
    ) public
        onlyByStatus(Status.RULE_SETTING)
        onlyOwner
        requireUnberMaxCount(lastDefinitelySendingRuleId)
        noZero(_ratio)
        canCreateSendingRule(_ratio, 1)   
        requireIsDestinationAddress(_destinationAddress)
    {
        lastDefinitelySendingRuleId++;

        definitelySendingRuleAddress[lastDefinitelySendingRuleId] = _destinationAddress;
        definitelySendingRuleRatio[lastDefinitelySendingRuleId] = _ratio;
        isDestinationAddress[_destinationAddress] = true;

        definitelySendingRuleRatioTotalAmount = definitelySendingRuleRatioTotalAmount + ratioAmount(_ratio);
    }

    function setSellerCommissionRatio(uint _sellerCommissionRatio) public onlyByStatus(Status.RULE_SETTING) onlyOwner noZero(_sellerCommissionRatio) canCreateSendingRule(_sellerCommissionRatio, 1) {
        sellerCommissionRatio = _sellerCommissionRatio;
        sellerCommissionRatioTotalAmount = ratioAmount(sellerCommissionRatio);
    }

    modifier requireIsDestinationAddress(address _destinationAddress) {
        require(isDestinationAddress[_destinationAddress] == false, "This address has already been added.");
        _;
    }

    modifier noZero(uint number) {
        require(number > 0, "noZero");
        _;

    }

    modifier requireUnberMaxCount(uint number) {
        require(number < MAX_COUNT, "requireUnberMaxCount");
        _;
    }

    modifier onlyOwnerWhenIsOnlyOwner {
        if (isOnlyOwner) {
            require(owner() == _msgSender(), "Ownable: caller is not the owner");
        }
        _;
    }

    modifier onlyByStatus(Status _status) {
        require(_status == status, "onlyByStatus");
        _;
    }

    modifier onlyByTokenSendingStatus(TokenSengingStatus _tokenSengingStatus) {
        require(_tokenSengingStatus == tokenSengingStatus, "onlyByTokenSendingStatus");
        _;
    }

    modifier requireRandomSendingRules() {
        require(lastRandomSendingRuleId > 0, "require random sending rules");
        _;
    }

    modifier requireRandomValue() {
        require(randomValue[index] != 0, "requireRandomValue");
        _;
    }

    modifier requireUnderMaxSendingCount(uint sendingCount) {
        require(MAX_SENDING_COUNT >= sendingCount, "requireUnderMaxSendingCount");
        _;
    }

    modifier requireGreaterThanLastRandomSendingRuleRatio(uint ratio) {
        require(randomSendingRuleRatio[lastRandomSendingRuleId] <= ratio, "requireGreaterThanLastRandomSendingRuleRatio");
        _;
    }

    /**
    * @notice Can it create a sending rule
    * @param _ratio Sending Rule ratio
    * @param _sendingCount SendingRule sending count
    */
    modifier canCreateSendingRule(uint _ratio, uint _sendingCount) {
        uint totalAmount = randomSendingRuleRatioTotalAmount + definitelySendingRuleRatioTotalAmount + sellerCommissionRatioTotalAmount + (ratioAmount(_ratio) * _sendingCount);
        require(
            totalAmount < baseTokenAmount, 
            "Only less than 100%"
        );
        _;
    }

    function ticketIdByTicketIds(uint _ticketIdsIndex) internal view returns(uint) {
        return _ticketIds[index][msg.sender][_ticketIdsIndex];
    }

    function ticketLastId(uint _index) external view returns(uint) {
        return _ticketLastId[_index];
    }

    function ticketCount(uint _index, uint ticketId) external view returns(uint) {
        return _ticketCount[_index][ticketId];
    }

    function ticketLastNumber(uint _index, uint ticketId) external view returns(uint) {
        return _ticketLastNumber[_index][ticketId];
    }

    function ticketReceivedAt(uint _index, uint ticketId) external view returns(uint) {
        return _ticketReceivedAt[_index][ticketId];
    }

    function participantCount(uint _index) external view returns(uint) {
        return _participantCount[_index];
    }

    function isParticipated(uint _index, address user) external view returns(bool) {
        return _isParticipated[_index][user];
    }

    function ticketIds(uint _index, address user) external view returns(uint[] memory) {
        return _ticketIds[_index][user];
    }

    function ticketHolder(uint _index, uint _ticketId) external view returns(address) {
        return _ticketHolder[_index][_ticketId];
    }

    function sellers(uint _index) external view returns(address[] memory) {
        return _sellers[_index];
    }

    function isSeller(uint _index, address seller) external view returns(bool) {
        return _isSeller[_index][seller];
    }

    function tokenAmountToSeller(uint _index, address seller) external view returns(uint) {
        return _tokenAmountToSeller[_index][seller];
    }

    /**
    * @notice ERC20 tokens collected by this contract
    */
    function totalSupply() public view returns(uint) {
        return erc20.balanceOf(address(this));
    }

    /**
    * @notice 
    */
    function randomSendingRatioAmount(uint _ratio, uint _sendingCount) private pure returns(uint) {
        return ratioAmount(_ratio) * _sendingCount;
    }

    /**
    * @notice 
    */
    function ratioAmount(uint _ratio) private pure returns(uint) {
        return baseTokenAmount / _ratio;
    }

    // change status ------>

    /**
    * @notice Change the status to accepting to be able to buy tickets.
    */
    function statusToAccepting() public onlyByStatus(Status.DONE) {
        if (index == 1) { 
            require(owner() == _msgSender());
        }
        status = Status.ACCEPTING;
        closeTimestamp = closeTimestamp + cycle;
        if (closeTimestamp < block.timestamp) {
            uint baseTimestamp = block.timestamp;
            // it fix to o'clock time if not divisible by 1 hour
            if ((block.timestamp % 1 hours) != 0) {
                baseTimestamp = baseTimestamp + (1 hours - (block.timestamp % 1 hours));
            }
            closeTimestamp = baseTimestamp + cycle;
        }
    }

    function statusToRandomValueGetting() public onlyByStatus(Status.ACCEPTING) {
        require(closeTimestamp < block.timestamp, "after closeTimestamp");
        status = Status.RANDOM_VALUE_GETTING;
        totalSupplyByIndex[index] = totalSupply();
        // production
        requestRandomWords();

        // test
        // randomValue[index] = 10000;
        // statusToTokenSending();
    }

    function statusToTokenSending() internal {
        tokenSengingStatus = TokenSengingStatus.SEND_TO_SELLER;
        status = Status.TOKEN_SENDING;
        currentRandomSendingRuleId = 1;
        currentRandomSendingRuleSendingCount = 1;
        currentDefinitelySendingId = 1;
    }

    function statusToDone() public onlyByStatus(Status.TOKEN_SENDING) {
        status = Status.DONE;
        index++;
    }

    function complatedRuleSetting() public onlyOwner onlyByStatus(Status.RULE_SETTING) requireRandomSendingRules {
        status = Status.DONE;
    }
    // <---------- change status

    // token sending ---------->
    // The cycle of token sending is: transfer of tokens to the SELLER, random transfer to the drawer, and  definitely sending.
    function sendToSeller() public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.SEND_TO_SELLER) requireRandomValue {
        require(_sellers[index][sendToSellerIndex] != address(0));
        address _seller = _sellers[index][sendToSellerIndex];
        uint tokenAmount = _tokenAmountToSeller[index][_seller];
        if ((_sellers[index].length - 1) == sendToSellerIndex) {
            sendToSellerIndex = 0;
            tokenSengingStatus = TokenSengingStatus.RANDOM_SEND;
        } else {
            sendToSellerIndex++;
        }
        erc20.transfer(_seller, tokenAmount);
    }

    function convertedNumber(uint number) private view returns (uint) {
        return uint(keccak256(abi.encode(number))) % _ticketLastNumber[index][_ticketLastId[index]];
    }

    function convertRandomValueToWinnerTicketNumber() public view returns (uint) {
        uint uniquRandamValue = randomValue[index] + convertedNumber(currentRandomSendingRuleId * MAX_SENDING_COUNT) + convertedNumber(currentRandomSendingRuleSendingCount);
        uniquRandamValue = convertedNumber(uniquRandamValue);
        if (uniquRandamValue == 0) {
            return _ticketLastNumber[index][_ticketLastId[index]];
        } else {
            return uniquRandamValue;
        }
    }

    function randomSend(uint _ticketId) public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.RANDOM_SEND) {
        require(_ticketLastId[index] >= _ticketId);
        require(_ticketId > 0, "require over then 0");
        uint winnerTicketNumber = convertRandomValueToWinnerTicketNumber();
        require(_ticketLastNumber[index][_ticketId - 1] < winnerTicketNumber && (_ticketLastNumber[index][_ticketId - 1] + _ticketCount[index][_ticketId]) >= winnerTicketNumber);

        uint tokenAmount = totalSupplyByIndex[index].div(randomSendingRuleRatio[currentRandomSendingRuleId]);
        erc20.transfer(_ticketHolder[index][_ticketId], tokenAmount);
        
        nextToRandomSend();
    }

    function nextToRandomSend() private {
        // When all the sending_counts have been transferred, the next random sending is performed.
        if (currentRandomSendingRuleSendingCount == randomSendingRuleSendingCount[currentRandomSendingRuleId]) {
            if (currentRandomSendingRuleId == lastRandomSendingRuleId) {
                // finished random sending and 
                tokenSengingStatus = TokenSengingStatus.DEFINITELY_SEND;
            } else {
                 // currentRandomSendingRuleId is set to plus one for the next Random Sending.
                currentRandomSendingRuleId++;
                currentRandomSendingRuleSendingCount = 1;
            }
        } else {
            // next random sending
            currentRandomSendingRuleSendingCount++;
        }
    }

    function definitelySend() public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.DEFINITELY_SEND) {
        // tokenAmount Calculation
        uint tokenAmount = totalSupplyByIndex[index].div(definitelySendingRuleRatio[currentDefinitelySendingId]);
        // sending token
        erc20.transfer(definitelySendingRuleAddress[currentDefinitelySendingId], tokenAmount);

        nextToDefinitelySend();
    }

    function nextToDefinitelySend() private {
        if (lastDefinitelySendingRuleId == currentDefinitelySendingId) {
            // finished
            statusToDone();
        } else {
            // next definitely sending
            currentDefinitelySendingId++;
        }
    }
    // <------------ token sending
}
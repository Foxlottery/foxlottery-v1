// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "contracts/IRandomValueGenerator.sol";
import "contracts/ILottery.sol";

/**
 * @title Lottery
 * @author Seiya Takahashi (github: https://github.com/PeterTakahashi)
 * @notice The owner can easily create a lottery by setting the closing time, the rules of the drawing, the commission to the seller, and the name.
 */
contract Lottery is Ownable, ILottery {
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
    uint private constant MAX_COUNT = 10;
    uint private constant MAX_SENDING_COUNT = 100;

    // constant
    string public name;
    string public symbol;
    uint public cycle; // Lottery time cycle
    uint public closeTimestamp;
    IERC20 public erc20; // erc20 token used for lottery
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

    // totalSupply
    mapping(uint => uint) public totalSupplyByIndex;

    // event count
    uint public index = 1;

    // ticket config
    uint public ticketPrice;

    // ticket
    mapping(uint => uint) public ticketLastId;
    mapping(uint => mapping(uint => uint)) private _ticketCount;
    mapping(uint => mapping(uint => uint)) private _ticketLastNumber;
    mapping(uint => mapping(address => uint[])) private _ticketIds;
    mapping(uint => mapping(uint => address)) private _ticketHolder;
    mapping(uint => mapping(uint => uint)) private _ticketReceivedAt;

    // participant
    mapping(uint => uint) public participantCount;
    mapping(uint => mapping(address => bool)) private _isParticipated;

    // seller
    uint public currentSellerId;
    mapping(uint => uint) public sellerLastId;
    mapping(uint => mapping(uint => address)) private _sellers;
    mapping(uint => mapping(address => bool)) private _isSeller;
    mapping(uint => mapping(address => uint)) private _tokenAmountToSeller;

    // random value
    mapping(uint => uint) public randomValue;

    IRandomValueGenerator public randomValueGenerator;

    event Ticket(uint ticketLastId);

    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _erc20,
        uint _ticketPrice,
        uint _cycle,
        uint _closeTimestamp
    )
    {
        require(_cycle != 0 && (_cycle % 1 hours) == 0);
        require((_closeTimestamp % 1 hours) == 0);
        require((_closeTimestamp > block.timestamp + _cycle));
        name = _name;
        symbol = _symbol;
        erc20 = _erc20;
        ticketPrice = _ticketPrice;
        cycle = _cycle;
        closeTimestamp = _closeTimestamp;
    }

     /**
    * @notice buy lottery ticket
    * @param __ticketCount Amount of lottery tickets
    * @param _seller ticket seller
    * @dev When you buy a lottery ticket, you lock the funds in a smart contract wallet.
    */
    function buyTicket(uint256 __ticketCount, address _seller) public payable onlyByStatus(Status.ACCEPTING) requireUnberMaxCount(_ticketIds[index][msg.sender].length) {
        uint tokenAmount = __ticketCount * ticketPrice;
        require(erc20.balanceOf(msg.sender) >= tokenAmount, "Not enough erc20 tokens.");

        // ticket
        ticketLastId[index]++;
        _ticketCount[index][ticketLastId[index]] = __ticketCount;
        _ticketLastNumber[index][ticketLastId[index]] = _ticketLastNumber[index][ticketLastId[index] - 1] + __ticketCount;

        _ticketIds[index][msg.sender].push(ticketLastId[index]);
        _ticketReceivedAt[index][ticketLastId[index]] = block.timestamp;

        _ticketHolder[index][ticketLastId[index]] = msg.sender;

        addParticipantCount(msg.sender);

        // Lock the Lottery in the contract
        erc20.transferFrom(msg.sender, address(this), tokenAmount);

        if (sellerCommissionRatio > 0) {
          if (!_isSeller[index][_seller]) {
            _isSeller[index][_seller] = true;
            sellerLastId[index]++;
            _sellers[index][sellerLastId[index]] = _seller;
          }
          _tokenAmountToSeller[index][_seller] = _tokenAmountToSeller[index][_seller] + tokenAmount.div(sellerCommissionRatio);
        }
        emit Ticket(ticketLastId[index]);
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
            participantCount[index] += 1;
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

    function setRandomValue(uint _randomValue) external {
        require(msg.sender == address(randomValueGenerator));
        randomValue[index] = _randomValue;
        statusToTokenSending();
    }

    function setRandomValueGenerator(IRandomValueGenerator _randomValueGenerator) external onlyOwner onlyByStatus(Status.RULE_SETTING) {
        randomValueGenerator = _randomValueGenerator;
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
            totalAmount <= baseTokenAmount, 
            "Only less than 100%"
        );
        _;
    }

    modifier requireRule100Percentage() {
        uint totalAmount = randomSendingRuleRatioTotalAmount + definitelySendingRuleRatioTotalAmount + sellerCommissionRatioTotalAmount;
        require(
            totalAmount == baseTokenAmount, 
            "require rule is 100%"
        );
        _;
    }

    function ticketIdByTicketIds(uint _ticketIdsIndex) internal view returns(uint) {
        return _ticketIds[index][msg.sender][_ticketIdsIndex];
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

    function isParticipated(uint _index, address user) external view returns(bool) {
        return _isParticipated[_index][user];
    }

    function ticketIds(uint _index, address user) external view returns(uint[] memory) {
        return _ticketIds[_index][user];
    }

    function ticketHolder(uint _index, uint _ticketId) external view returns(address) {
        return _ticketHolder[_index][_ticketId];
    }

    function seller(uint _index, uint _sellerId) external view returns(address) {
        return _sellers[_index][_sellerId];
    }

    function isSeller(uint _index, address _seller) external view returns(bool) {
        return _isSeller[_index][_seller];
    }

    function tokenAmountToSeller(uint _index, address _seller) external view returns(uint) {
        return _tokenAmountToSeller[_index][_seller];
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
        randomValueGenerator.requestRandomWords();
    }

    function statusToTokenSending() private {
        tokenSengingStatus = TokenSengingStatus.SEND_TO_SELLER;
        status = Status.TOKEN_SENDING;
        currentRandomSendingRuleId = 1;
        currentRandomSendingRuleSendingCount = 1;
        currentDefinitelySendingId = 1;
        currentSellerId = 1;
    }

    function statusToDone() public onlyByStatus(Status.TOKEN_SENDING) {
        status = Status.DONE;
        index++;
    }

    function complatedRuleSetting() public onlyOwner onlyByStatus(Status.RULE_SETTING) requireRule100Percentage requireRandomSendingRules {
        require(address(randomValueGenerator) != address(0));
        status = Status.DONE;
    }
    // <---------- change status

    // token sending ---------->
    // The cycle of token sending is: transfer of tokens to the SELLER, random transfer to the drawer, and  definitely sending.
    function sendToSeller() public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.SEND_TO_SELLER) requireRandomValue {
        require(_sellers[index][currentSellerId] != address(0));
        address _seller = _sellers[index][currentSellerId];
        uint tokenAmount = _tokenAmountToSeller[index][_seller];
        erc20.transfer(_seller, tokenAmount);
        if (sellerLastId[index] == currentSellerId) {
            tokenSengingStatus = TokenSengingStatus.RANDOM_SEND;
        } else {
            currentSellerId++;
        }
    }

    function convertedNumber(uint number) private view returns (uint) {
        return uint(keccak256(abi.encode(number))) % _ticketLastNumber[index][ticketLastId[index]];
    }

    function convertRandomValueToWinnerTicketNumber() public view returns (uint) {
        uint uniquRandamValue = randomValue[index] + convertedNumber(currentRandomSendingRuleId * MAX_SENDING_COUNT) + convertedNumber(currentRandomSendingRuleSendingCount);
        uniquRandamValue = convertedNumber(uniquRandamValue);
        if (uniquRandamValue == 0) {
            return _ticketLastNumber[index][ticketLastId[index]];
        } else {
            return uniquRandamValue;
        }
    }

    function randomSend(uint _ticketId) public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.RANDOM_SEND) {
        require(ticketLastId[index] >= _ticketId);
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

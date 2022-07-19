// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "hardhat/console.sol";
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
    // If there are many winners, gas costs will increase and lotteries will take longer to reunite.
    // SENDING_COUNT is necessary to ensure that the number of LOTTERY winners is not too large.
    uint private constant MAX_SENDING_COUNT = 100;
    uint private constant MINIMUM_CYCLE_TIME = 1 hours;

    // constant
    string public name;
    string public symbol;
    uint public cycle; // Lottery time cycle
    uint public closeTimestamp; // Lottery closing time
    IERC20 public erc20; // erc20 token used for lottery
    uint public immutable baseTokenAmount = 10 ** 18;

    // sellerCommission
    // A seller is always required to purchase lottery tickets.
    // The seller will be remitted the sales commission after the lottery ticket has been completed.
    uint public sellerCommissionRatio;
    uint public sellerCommissionRatioTotalAmount;

    // RandomSendingRule
    // After the lottery closes, the ERC20 tokens are transferred to the winners based on the RandomSendingRule.
    uint public lastRandomSendingRuleId;
    mapping(uint => uint) public randomSendingRuleRatio;
    mapping(uint => uint) public randomSendingRuleSendingCount;
    uint public randomSendingRuleRatioTotalAmount;
    uint public currentRandomSendingRuleId;
    uint public currentRandomSendingRuleSendingCount;

    /// definitelySendingRule
    // After the lottery is closed, an ERC20 token is transferred to the definitivelySendingRuleAddress based on the definitivelySendingRule.
    uint public lastDefinitelySendingRuleId;
    mapping(uint => address) public definitelySendingRuleAddress;
    mapping(uint => uint) public definitelySendingRuleRatio;
    uint public definitelySendingRuleRatioTotalAmount;
    uint public currentDefinitelySendingId;
    mapping(address => bool) public isDestinationAddress;

    // totalSupply
    mapping(uint => uint) public totalSupplyByIndex;

    // event count
    // After the lotteries are completed, the index is plus one.
    uint public index = 1;

    // ticket config
    uint public ticketPrice;

    // ticket
    mapping(uint => uint) public ticketLastId;
    mapping(uint => mapping(uint => uint)) private _ticketNumberRange;
    mapping(uint => mapping(uint => uint)) private _ticketLastNumber;
    mapping(uint => mapping(address => uint[])) private _ticketIds;
    mapping(uint => mapping(uint => address)) private _ticketHolder;
    mapping(uint => mapping(uint => uint)) private _ticketReceivedAt;

    // participant
    mapping(uint => uint) public participantCount;

    // seller
    uint public currentSellerId;
    mapping(uint => uint) public sellerLastId;
    mapping(uint => mapping(uint => address)) private _sellers;
    mapping(uint => mapping(address => uint)) private _tokenAmountOfSeller;

    // random value
    mapping(uint => uint) public randomValue;

    IRandomValueGenerator public randomValueGenerator;

    event Ticket(uint ticketId);

    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _erc20,
        uint _ticketPrice,
        uint _cycle,
        uint _closeTimestamp
    )
    {
        require(_cycle != 0 && (_cycle % MINIMUM_CYCLE_TIME) == 0);
        require((_closeTimestamp % MINIMUM_CYCLE_TIME) == 0);
        require((_closeTimestamp > block.timestamp + _cycle));
        name = _name;
        symbol = _symbol;
        erc20 = _erc20;
        ticketPrice = _ticketPrice;
        cycle = _cycle;
        closeTimestamp = _closeTimestamp;
    }

    /**
    * @notice buy lottery ticket. require status is accepting.
    * @param __ticketNumberRange Amount of lottery tickets
    * @param _seller ticket seller. Seller is required.
    * @dev When you buy a lottery ticket, you lock the funds in a smart contract wallet. Cannot have more than MAX_COUNT tickets. After the completion of this lottery, The seller is remitted the token amount of ticket token amount / sellerCommissionRatio.
    */
    function buyTicket(uint256 __ticketNumberRange, address _seller) public
        payable 
        onlyByStatus(Status.ACCEPTING)
        requireUnberMaxCount(_ticketIds[index][msg.sender].length)
    {
        uint tokenAmount = __ticketNumberRange * ticketPrice;
        require(erc20.balanceOf(msg.sender) >= tokenAmount, "Not enough erc20 tokens.");

        addParticipantCount(msg.sender);
        // ticket
        ticketLastId[index]++;
        _ticketNumberRange[index][ticketLastId[index]] = __ticketNumberRange;
        _ticketLastNumber[index][ticketLastId[index]] = _ticketLastNumber[index][ticketLastId[index] - 1] + __ticketNumberRange;

        _ticketIds[index][msg.sender].push(ticketLastId[index]);
        _ticketReceivedAt[index][ticketLastId[index]] = block.timestamp;

        _ticketHolder[index][ticketLastId[index]] = msg.sender;

        // Lock the Lottery in the contract
        erc20.transferFrom(msg.sender, address(this), tokenAmount);

        if (sellerCommissionRatio > 0) {
          if (!isSeller(index, _seller)) {
            sellerLastId[index]++;
            _sellers[index][sellerLastId[index]] = _seller;
          }
          _tokenAmountOfSeller[index][_seller] = _tokenAmountOfSeller[index][_seller] + tokenAmount.div(sellerCommissionRatio);
        }
        emit Ticket(ticketLastId[index]);
    }

    /**
    * @notice send a ticket.
    * @param ticketIdsIndex index of ticket ids to be sent
    * @param to Ticket destination address
    * @dev Delete the msg.sender's ticket and add a ticket to the destination address. Add the participant you are sending to as a participant
    */
    function sendTicket(uint ticketIdsIndex, address to) public onlyByStatus(Status.ACCEPTING) requireUnberMaxCount(_ticketIds[index][to].length) {
        require(isParticipated(index, msg.sender), "You must be have been ticket");
        uint ticketId = _ticketIds[index][msg.sender][ticketIdsIndex];

        addParticipantCount(to);

        // remove
        _ticketIds[index][msg.sender][ticketIdsIndex] = _ticketIds[index][msg.sender][_ticketIds[index][msg.sender].length - 1];
        _ticketIds[index][msg.sender].pop();

        // add
        _ticketIds[index][to].push(ticketId);
        _ticketHolder[index][ticketId] = to;
    }

    /**
    * @notice Add Participant count on current lottery event if you are not already a participant
    * @param participant participant　wallet address
    */
    function addParticipantCount(address participant) internal {
        if (!isParticipated(index, participant)) {
            // lottery purchaser add participants
            participantCount[index] += 1;
        }
    }

    /**
    * @notice create random sending rule
    * @param _ratio random sending rule ratio
    * @param _sendingCount random sending rule sending count
    * @dev This function can only be executed immediately after the contract is created, in order to prevent the rules from being changed after the lottery ticket is purchased.
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
    * @dev This function can only be executed immediately after the contract is created, in order to prevent the rules from being changed after the lottery ticket is purchased.
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

    /**
    * @notice set seller commission ratio
    * @param _sellerCommissionRatio seller commision ratio
    * @dev This function can only be executed immediately after the contract is created, in order to prevent the rules from being changed after the lottery ticket is purchased.
    */
    function setSellerCommissionRatio(uint _sellerCommissionRatio) public onlyByStatus(Status.RULE_SETTING) onlyOwner noZero(_sellerCommissionRatio) canCreateSendingRule(_sellerCommissionRatio, 1) {
        sellerCommissionRatio = _sellerCommissionRatio;
        sellerCommissionRatioTotalAmount = ratioAmount(sellerCommissionRatio);
    }

    /**
    * @notice set random value
    * @param _randomValue random value
    * @dev This function can only be executed with a random value generator contract. This random value is used to determine lottery winners. After the random value is set, change status to token sending.
    */
    function setRandomValue(uint _randomValue) external onlyByStatus(Status.RANDOM_VALUE_GETTING) {
        require(msg.sender == address(randomValueGenerator));
        randomValue[index] = _randomValue;
        statusToTokenSending();
    }

    /**
    * @notice set random value generator
    * @param _randomValueGenerator random value generator contract address
    * @dev After deploying the random value generator contract, the owner sets it.
    */
    function setRandomValueGenerator(IRandomValueGenerator _randomValueGenerator) external onlyOwner onlyByStatus(Status.RULE_SETTING) {
        randomValueGenerator = _randomValueGenerator;
    }

    /**
    * @notice require is destination address
    * @param _destinationAddress destination address
    */
    modifier requireIsDestinationAddress(address _destinationAddress) {
        require(isDestinationAddress[_destinationAddress] == false, "This address has already been added.");
        _;
    }

    /**
    * @param number number
    */
    modifier noZero(uint number) {
        require(number > 0, "noZero");
        _;

    }

    /**
    * @param number number
    */
    modifier requireUnberMaxCount(uint number) {
        require(number < MAX_COUNT, "requireUnberMaxCount");
        _;
    }

    /**
    * @param _status status
    */
    modifier onlyByStatus(Status _status) {
        require(_status == status, "onlyByStatus");
        _;
    }

    /**
    * @notice check token sending status
    * @param _tokenSengingStatus token senging status
    * @dev The _tokenSengingStatus passed in the argument and the contract's tokenSengingStatus must be the same.
    */
    modifier onlyByTokenSendingStatus(TokenSengingStatus _tokenSengingStatus) {
        require(_tokenSengingStatus == tokenSengingStatus, "onlyByTokenSendingStatus");
        _;
    }

    /**
    * @notice require random value. The current index lottery random numbers must have been obtained.
    * @dev The random number is set from the RandomValueGenerator Contract by the setRandomValue method.
    */
    modifier requireRandomValue() {
        require(randomValue[index] != 0, "requireRandomValue");
        _;
    }

    /**
    * @notice The sendingCount argument must be less than or equal to MAX_SENDING_COUNT
    * @param sendingCount sending count
    * @dev This method exists to limit the number of remittances of lottery results.
    */
    modifier requireUnderMaxSendingCount(uint sendingCount) {
        require(MAX_SENDING_COUNT >= sendingCount, "requireUnderMaxSendingCount");
        _;
    }

    /**
    * @notice require generater than Last random sending rule ratio
    * @param _randomSendingRuleRatio random sending rule ratio
    * @dev The random sending rule must increase as RandomSendingRuleId increases.　The minimum RandomSendingRuleRatio with a RandomSendingRuleId of 1 will remit the maximum ratio.
    */
    modifier requireGreaterThanLastRandomSendingRuleRatio(uint _randomSendingRuleRatio) {
        require(randomSendingRuleRatio[lastRandomSendingRuleId] <= _randomSendingRuleRatio, "requireGreaterThanLastRandomSendingRuleRatio");
        _;
    }

    /**
    * @notice can create sending rule. This modifier is necessary to ensure that the total ratio does not exceed 100%.
    * @param _ratio Sending Rule ratio
    * @param _sendingCount SendingRule sending count
    * @dev If totalAmount is greater than baseTokenAmount, the total ratio is greater than 100%.
    */
    modifier canCreateSendingRule(uint _ratio, uint _sendingCount) {
        uint totalAmount = currentTotalAmount() + (ratioAmount(_ratio) * _sendingCount);
        require(
            totalAmount <= baseTokenAmount, 
            "Only less than 100%"
        );
        _;
    }

    function currentTotalAmount() private view returns(uint) {
        return randomSendingRuleRatioTotalAmount + definitelySendingRuleRatioTotalAmount + sellerCommissionRatioTotalAmount;
    }

    /**
    * @notice ticket number range
    * @param _index index
    * @param ticketId ticket id
    */
    function ticketNumberRange(uint _index, uint ticketId) external view returns(uint) {
        return _ticketNumberRange[_index][ticketId];
    }

    /**
    * @notice ticket last number
    * @param _index index
    * @param ticketId ticket id
    */
    function ticketLastNumber(uint _index, uint ticketId) external view returns(uint) {
        return _ticketLastNumber[_index][ticketId];
    }

    /**
    * @notice ticket received at
    * @param _index index
    * @param ticketId ticket id
    */
    function ticketReceivedAt(uint _index, uint ticketId) external view returns(uint) {
        return _ticketReceivedAt[_index][ticketId];
    }

    /**
    * @notice ticket holder
    * @param _index index
    * @param ticketId ticket id
    */
    function ticketHolder(uint _index, uint ticketId) external view returns(address) {
        return _ticketHolder[_index][ticketId];
    }

    /**
    * @notice ticket ids
    * @param _index index
    * @param participant participant
    */
    function ticketIds(uint _index, address participant) external view returns(uint[] memory) {
        return _ticketIds[_index][participant];
    }

    /**
    * @notice participated?
    * @param _index index
    * @param participant participant
    * @return If participant participated true will be returned
    * @dev If user have a number of tickets greater than zero, user is considered to have participated.
    */
    function isParticipated(uint _index, address participant) public view returns(bool) {
        return _ticketIds[_index][participant].length > 0;
    }

    /**
    * @notice seller
    * @param _index index
    * @param _sellerId seller id
    */
    function seller(uint _index, uint _sellerId) external view returns(address) {
        return _sellers[_index][_sellerId];
    }

    /**
    * @notice seller?
    * @param _index index
    * @param _seller seller wallet address
    * @return If _tokenAmountOfSeller is greater than 0, it shall be seller.
    */
    function isSeller(uint _index, address _seller) public view returns(bool) {
        return _tokenAmountOfSeller[_index][_seller] > 0;
    }

    /**
    * @notice token amount　to　seller
    * @param _index index
    * @param _seller seller wallet address
    */
    function tokenAmountOfSeller(uint _index, address _seller) external view returns(uint) {
        return _tokenAmountOfSeller[_index][_seller];
    }


    /**
    * @notice ERC20 tokens collected by this contract
    */
    function totalSupply() public view returns(uint) {
        return erc20.balanceOf(address(this));
    }

    /**
    * @notice random sending ratio amount
    * @param _ratio ratio
    * @param _sendingCount sending count
    */
    function randomSendingRatioAmount(uint _ratio, uint _sendingCount) private pure returns(uint) {
        return ratioAmount(_ratio) * _sendingCount;
    }

    /**
    * @notice ratio amount
    * @param _ratio ratio
    */
    function ratioAmount(uint _ratio) private pure returns(uint) {
        return baseTokenAmount / _ratio;
    }

    // change status ------>

    /**
    * @notice status to accepting
    * @dev When the status becomes ACCEPTING, the ticket can be purchased.
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
            if ((block.timestamp % MINIMUM_CYCLE_TIME) != 0) {
                baseTimestamp = baseTimestamp + (MINIMUM_CYCLE_TIME - (block.timestamp % MINIMUM_CYCLE_TIME));
            }
            closeTimestamp = baseTimestamp + cycle;
        }
    }

    /**
    * @notice status to random value getting
    * @dev When the status becomes random value getting, the random value generator contract starts generating random numbers.
    */
    function statusToRandomValueGetting() public onlyByStatus(Status.ACCEPTING) {
        require(closeTimestamp < block.timestamp, "after closeTimestamp");
        status = Status.RANDOM_VALUE_GETTING;
        totalSupplyByIndex[index] = totalSupply();
        randomValueGenerator.requestRandomWords();
    }

    /**
    * @notice status to token sending
    * @dev This method is executed only from setRandomValue. When the status is changed to TOKEN_SENDING, RANDOM SENDING and DEFINITELY SENDING and remittance to the SELLER are made.
    */
    function statusToTokenSending() private {
        tokenSengingStatus = TokenSengingStatus.SEND_TO_SELLER;
        status = Status.TOKEN_SENDING;
        currentRandomSendingRuleId = 1;
        currentRandomSendingRuleSendingCount = 1;
        currentDefinitelySendingId = 1;
        currentSellerId = 1;
    }

    /**
    * @notice status to done
    * @dev This method is executed only from nextToDefinitelySend.
    */
    function statusToDone() private onlyByStatus(Status.TOKEN_SENDING) {
        status = Status.DONE;
        index++;
    }

    /**
    * @notice completed rule setting
    * @dev Can only be executed when ruleTotalRatio is 100%.　It will be done.
    * A random value generator contract must be set.
    * When status is done, it is possible to change status to ACCEPTING.
    * 
    */
    function complatedRuleSetting() public onlyOwner onlyByStatus(Status.RULE_SETTING) {
        // Required to execute the complatedRuleSetting method. The total ratio must be 100% when complated Rule Setting.
        require(currentTotalAmount() == baseTokenAmount, "require rule is 100%");
        require(lastRandomSendingRuleId > 0, "require random sending rules");
        require(address(randomValueGenerator) != address(0));
        status = Status.DONE;
    }
    // <---------- change status

    // token sending ---------->
    // The cycle of token sending is: transfer of tokens to the SELLER, random transfer to the drawer, and  definitely sending.

    /**
    * @notice send to seller
    * @dev Transfer of erc20 token to the seller. When the remittance to the seller is completed, change the STATUS to RANDOM SENDING.
    */
    function sendToSeller() public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.SEND_TO_SELLER) requireRandomValue {
        require(_sellers[index][currentSellerId] != address(0));
        address _seller = _sellers[index][currentSellerId];
        uint tokenAmount = _tokenAmountOfSeller[index][_seller];
        erc20.transfer(_seller, tokenAmount);
        if (sellerLastId[index] == currentSellerId) {
            tokenSengingStatus = TokenSengingStatus.RANDOM_SEND;
        } else {
            currentSellerId++;
        }
    }

    /**
    * @notice converted　Number
    * @param number number
    * @dev This method is required to generate unique random numbers
    */
    function convertedNumber(uint number) private view returns (uint) {
        return uint(keccak256(abi.encode(number))) % _ticketLastNumber[index][ticketLastId[index]];
    }

    /**
    * @notice convert　random value to winner ticket number
    * @dev This method is required to generate unique random numbers
    */
    function convertRandomValueToWinnerTicketNumber() public view returns (uint) {
        uint uniquRandamValue = randomValue[index] + convertedNumber(currentRandomSendingRuleId * MAX_SENDING_COUNT) + convertedNumber(currentRandomSendingRuleSendingCount);
        uniquRandamValue = convertedNumber(uniquRandamValue);
        if (uniquRandamValue == 0) {
            return _ticketLastNumber[index][ticketLastId[index]];
        } else {
            return uniquRandamValue;
        }
    }

    /**
    * @notice random send
    * @param _ticketId ticket id
    * @dev This method remits ERC20 tokens to winners determined based on random numbers.
    * Since there are multiple tickets and the process of finding winners from random numbers on the blockchain network would incur a lot of gas costs,
    * which ticket is the winner is found by an RDB outside the blockchain.
    */
    function randomSend(uint _ticketId) public
        onlyByStatus(Status.TOKEN_SENDING)
        onlyByTokenSendingStatus(TokenSengingStatus.RANDOM_SEND)
    {
        require(ticketLastId[index] >= _ticketId);
        require(_ticketId > 0, "require over then 0");
        uint winnerTicketNumber = convertRandomValueToWinnerTicketNumber();
        require(
            _ticketLastNumber[index][_ticketId - 1] < winnerTicketNumber &&
            (_ticketLastNumber[index][_ticketId - 1] + _ticketNumberRange[index][_ticketId]) >= winnerTicketNumber
        );

        uint tokenAmount = totalSupplyByIndex[index].div(randomSendingRuleRatio[currentRandomSendingRuleId]);
        erc20.transfer(_ticketHolder[index][_ticketId], tokenAmount);
        
        nextToRandomSend();
    }

    /**
    * @notice next to random send
    * @dev If the next random transmission is needed, change currentRandomSendingRuleId or currentRandomSendingRuleSendingCount to send the next random transmission.
    * After all random transmissions are completed, change TokenSengingStatus to DEFINITELY_SEND.
    */
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

    /**
    * @notice definitely send
    * @dev Transfer ERC20 tokens to definitivelySendingRuleAddress.
    */
    function definitelySend() public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.DEFINITELY_SEND) {
        // tokenAmount Calculation
        uint tokenAmount = totalSupplyByIndex[index].div(definitelySendingRuleRatio[currentDefinitelySendingId]);
        // sending token
        erc20.transfer(definitelySendingRuleAddress[currentDefinitelySendingId], tokenAmount);

        nextToDefinitelySend();
    }

    /**
    * @notice net to definitely send
    * @dev When all DEFINITELY SEND is completed, set status to done.
    */
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

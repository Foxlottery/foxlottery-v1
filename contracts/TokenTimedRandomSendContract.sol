// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// chainlink
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract TokenTimedRandomSendContract is VRFConsumerBaseV2, Ownable {
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
    uint constant MAX_RULE_COUNT = 20;
    uint constant MAX_SENDING_COUNT = 1000;

    // constant
    string public name;
    string public symbol;
    uint public closeTimestamp;
    IERC20 public erc20; // erc20 token used for lottery
    bool public isOnlyOwner;
    uint public immutable baseTokenAmount = 10 ** 18;

    // sellerCommission
    uint public sellerCommissionRatio;
    uint public sellerCommissionRatioTotalAmount;
    // RandomSendingRule
    uint public lastRandomSendingRuleId;  // TODO: 上限数を制限する必要がある
    mapping(uint => uint) public randomSendingRuleRatio;
    mapping(uint => uint) public randomSendingRuleSendingCount;
    uint public randomSendingRuleRatioTotalAmount;
    uint public currentRandomSendingRuleId;
    uint public currentRandomSendingRuleSendingCount;
    /// definitelySendingRule
    uint public lastDefinitelySendingRuleId;
    mapping(uint => address) public definitelySendingRuleAddress;
    mapping(uint => uint) private definitelySendingRuleRatio;
    uint public definitelySendingRuleRatioTotalAmount;
    mapping(uint => uint) public totalSupplyByIndex;
    uint public currentDefinitelySendingId;

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
    mapping(uint => mapping(address => uint[])) private _ticketIds; // TODO: 上限数を制限する必要がある
    mapping(uint => mapping(uint => address)) private _ticketHolder;
    mapping(uint => mapping(uint => uint)) private _ticketReceivedAt;

    // participant
    mapping(uint => uint) private _participantCount;
    mapping(uint => mapping(address => bool)) public _isParticipated;

    // seller
    uint public sendToSellerIndex;
    mapping(uint => address[]) public _sellers;
    mapping(uint => mapping(address => bool)) public _isSeller;
    mapping(uint => mapping(address => uint)) public _tokenAmountToSeller;

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
        uint64 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(vrfCoordinator)
    {
        name = _name;
        symbol = _symbol;
        erc20 = _erc20;
        ticketPrice = _ticketPrice;
        isOnlyOwner = _isOnlyOwner;

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
    * onlyOwnerWhenIsOnlyOwner オーナーだけがチケットを購入できるようにする or 誰でもチケットを購入できるようにする
    */
    function buyTicket(uint256 __ticketCount, address seller) public payable onlyByStatus(Status.ACCEPTING) onlyOwnerWhenIsOnlyOwner {
        uint tokenAmount = __ticketCount * ticketPrice;
        require(erc20.balanceOf(msg.sender) >= tokenAmount, "TokenTimedRandomSendContract: Not enough erc20 tokens.");

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

    function sendTicket(uint ticketIdsIndex, address to) public onlyByStatus(Status.ACCEPTING) onlyOwner {
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
        requireLessThanMaxRuleCount(lastRandomSendingRuleId)
        noZero(_ratio)
        noZero(_sendingCount)
        canCreateSendingRule(_ratio, _sendingCount)
        requireUnderMaxSendingCount(_sendingCount)
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
        requireLessThanMaxRuleCount(lastDefinitelySendingRuleId)
        noZero(_ratio)
        canCreateSendingRule(_ratio, 1) 
    {
        lastDefinitelySendingRuleId++;

        definitelySendingRuleAddress[lastDefinitelySendingRuleId] = _destinationAddress;
        definitelySendingRuleRatio[lastDefinitelySendingRuleId] = _ratio;

        definitelySendingRuleRatioTotalAmount = definitelySendingRuleRatioTotalAmount + ratioAmount(_ratio);
    }

    function setSellerCommissionRatio(uint _sellerCommissionRatio) public onlyByStatus(Status.RULE_SETTING) onlyOwner noZero(_sellerCommissionRatio) canCreateSendingRule(_sellerCommissionRatio, 1) {
        sellerCommissionRatio = _sellerCommissionRatio;
        sellerCommissionRatioTotalAmount = ratioAmount(sellerCommissionRatio);
    }

    modifier noZero(uint number) {
        require(number > 0);
        _;

    }

    modifier requireLessThanMaxRuleCount(uint id) {
        require(id < MAX_RULE_COUNT);
        _;
    }

    modifier onlyOwnerWhenIsOnlyOwner {
        if (isOnlyOwner) {
            require(owner() == _msgSender(), "Ownable: caller is not the owner");
        }
        _;
    }

    modifier onlyByStatus(Status _status) {
        require(_status == status);
        _;
    }

    modifier onlyByTokenSendingStatus(TokenSengingStatus _tokenSengingStatus) {
        require(_tokenSengingStatus == tokenSengingStatus);
        _;
    }

    modifier requireRandomSendingRules() {
        require(lastRandomSendingRuleId > 0, "require random sending rules");
        _;
    }

    modifier requireRandomValue() {
        require(randomValue[index] != 0);
        _;
    }

    modifier requireUnderMaxSendingCount(uint sendingCount) {
        require(MAX_SENDING_COUNT >= sendingCount);
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
            "TimedRandomSendContract: Only less than 100%"
        );
        _;
    }

    function ticketIdByTicketIds(uint _ticketIdsIndex) internal view returns(uint) {
        return _ticketIds[index][msg.sender][_ticketIdsIndex];
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

    // public をexternalにする
    function ticketHolder(uint _index, uint _ticketId) public view returns(address) {
        return _ticketHolder[_index][_ticketId];
    }

    function sellers(uint _index) public view returns(address[] memory) {
        return _sellers[_index];
    }

    function isSeller(uint _index, address seller) public view returns(bool) {
        return _isSeller[_index][seller];
    }

    function tokenAmountToSeller(uint _index, address seller) public view returns(uint) {
        return _tokenAmountToSeller[_index][seller];
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

    // change status ------>
    // オーナーでなくても、スタートできるようにしたい。
    function statusToAccepting(uint _closeTimestamp) public onlyOwner onlyByStatus(Status.DONE) {
        require(_closeTimestamp > block.timestamp, "closeTimestamp require after block.timestamp");
        closeTimestamp = _closeTimestamp;
        status = Status.ACCEPTING;
    }

    // TODO: chainlink vrfからのデータの取得を失敗する可能性があることを考慮する
    // リスク回避の方法としては、長時間vrfからの応答がなければ、受け取った費用を戻すようにする
    function statusToRandomValueGetting() public onlyByStatus(Status.ACCEPTING) {
        require(closeTimestamp < block.timestamp, "after closeTimestamp");
        status = Status.RANDOM_VALUE_GETTING;
        totalSupplyByIndex[index] = totalSupply();
        // production
        // requestRandomWords();

        // dev
        randomValue[index] = 10000;
        statusToTokenSending();
    }

    function statusToTokenSending() private {
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

    // TODO: random sendをseller sendより先にする
    function sendToSeller() public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.SEND_TO_SELLER) requireRandomValue {
        require(_sellers[index][sendToSellerIndex] != address(0));
        address _seller = _sellers[index][sendToSellerIndex];
        uint tokenAmount = _tokenAmountToSeller[index][_seller];
        erc20.transfer(_seller, tokenAmount);
        if ((_sellers[index].length - 1) == sendToSellerIndex) {
            sendToSellerIndex = 0;
            tokenSengingStatus = TokenSengingStatus.RANDOM_SEND;
        } else {
            sendToSellerIndex++;
        }
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
        // sending_countの人数分の送金が完了したら、次のrandon sending ruleにいく、
        if (currentRandomSendingRuleSendingCount == randomSendingRuleSendingCount[currentRandomSendingRuleId]) {
            if (currentRandomSendingRuleId == lastRandomSendingRuleId) {
                // randam sendは終了
                tokenSengingStatus = TokenSengingStatus.DEFINITELY_SEND;
            } else {
                 // currentRandomSendingRuleIdをプラス１する
                currentRandomSendingRuleId++;
                currentRandomSendingRuleSendingCount = 1;
            }
        } else {
            // 次のsending countへ移る
            // 引数で_ticketIdをとるが、スマートコントラクトで承認する処理は必要になる, スマートコントラクトの処理の負荷を下げるためにこの処理をする
            currentRandomSendingRuleSendingCount++;
        }
    }

    function definitelySend() public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.DEFINITELY_SEND) {
        // 送金量の計算
        uint tokenAmount = totalSupplyByIndex[index].div(definitelySendingRuleRatio[currentDefinitelySendingId]);
        // 送金
        erc20.transfer(definitelySendingRuleAddress[currentDefinitelySendingId], tokenAmount);

        nextToDefinitelySend();
    }

    function nextToDefinitelySend() private {
        if (lastDefinitelySendingRuleId == currentDefinitelySendingId) {
            // 終了
            statusToDone();
        } else {
            currentDefinitelySendingId++;
        }
    }
}
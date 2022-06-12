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

    // constant
    string public name;
    string public symbol;
    uint public closeTimestamp;
    IERC20 public erc20; // erc20 token used for lottery
    uint public sellerCommission;
    bool public isOnlyOwner;
    uint public immutable baseTokenAmount = 10 ** 18;
    // RandomSendingRule
    uint[] public randomSendingRuleIds;
    mapping(uint => uint) public randomSendingRuleRatio;
    mapping(uint => uint) public randomSendingRuleSendingCount;
    uint public randomSendingRuleRatioTotalAmount;
    uint public currentRandomSendingRuleIndex;
    uint public currentRandomSendingRuleSendingCount = 1;
    /// definitelySendingRule
    uint[] public definitelySendingRuleIds;
    mapping(uint => address) public definitelySendingRuleAddress;
    mapping(uint => uint) private definitelySendingRuleRatio;
    uint public definitelySendingRuleRatioTotalAmount;
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
        uint _sellerCommission,
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
        sellerCommission = _sellerCommission;
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
        _tokenAmountToSeller[index][seller] = _tokenAmountToSeller[index][seller] + tokenAmount.div(sellerCommission);
    }

    function sendTicket(uint ticketIdsIndex, address to) public onlyByStatus(Status.ACCEPTING) onlyOwner {
        uint ticketId = ticketIdFromTicketIds(ticketIdsIndex);

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
    // TODO: ratioとcountが0より大きいことをvalidationかける
    function createRandomSendingRule(uint _ratio, uint _sendingCount) public onlyByStatus(Status.RULE_SETTING) onlyOwner canCreateSendingRule(_ratio, _sendingCount) {
        uint id = randomSendingRuleIds.length + 1;
        randomSendingRuleIds.push(id);
        randomSendingRuleRatio[id] = _ratio;
        randomSendingRuleSendingCount[id] = _sendingCount;

        randomSendingRuleRatioTotalAmount = randomSendingRuleRatioTotalAmount + randomSendingRatioAmount(_ratio, _sendingCount);
    }

    /**
    * @notice delete random sending rule
    * @param randomSendingRuleIndex random sending rule index
    */
    function deleteRandomSendingRule(uint randomSendingRuleIndex) public onlyByStatus(Status.RULE_SETTING) onlyOwner {
        uint id = randomSendingRuleIds[randomSendingRuleIndex];
        require(randomSendingRuleIds[randomSendingRuleIndex] != 0, "deleteRandomSendingRule: randomSendingRuleId not found");
        randomSendingRuleRatioTotalAmount = randomSendingRuleRatioTotalAmount - randomSendingRatioAmount(randomSendingRuleRatio[id], randomSendingRuleSendingCount[id]);
        randomSendingRuleIds[randomSendingRuleIndex] = randomSendingRuleIds[randomSendingRuleIds.length - 1];
        randomSendingRuleIds.pop();
        delete randomSendingRuleRatio[id];
        delete randomSendingRuleSendingCount[id];
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
    ) public onlyByStatus(Status.RULE_SETTING) onlyOwner canCreateSendingRule(_ratio, 1) {
        uint id = lastDefinitelySendingRuleIds() + 1;
        definitelySendingRuleIds.push(id);
        definitelySendingRuleAddress[id] = _destinationAddress;
        definitelySendingRuleRatio[id] = _ratio;

        definitelySendingRuleRatioTotalAmount = definitelySendingRuleRatioTotalAmount + ratioAmount(_ratio);
    }

    /**
    * @notice delete definitely sending rule
    * @param definitelySendingRuleIndex definitely sending rule index
    */
    function deleteDefinitelySendingRule(uint definitelySendingRuleIndex) public onlyByStatus(Status.RULE_SETTING) onlyOwner {
        uint id = definitelySendingRuleIds[definitelySendingRuleIndex];
        require(definitelySendingRuleIds[definitelySendingRuleIndex] != 0, "deleteDefinitelySendingRule: definitelySendingRuleId not found");
        definitelySendingRuleIds[definitelySendingRuleIndex] = definitelySendingRuleIds[definitelySendingRuleIds.length - 1];
        definitelySendingRuleIds.pop();
        definitelySendingRuleRatioTotalAmount = definitelySendingRuleRatioTotalAmount - ratioAmount(definitelySendingRuleRatio[id]);
        delete definitelySendingRuleAddress[id];
        delete definitelySendingRuleRatio[id];
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
        require(randomSendingRuleIds.length > 0, "require random sending rules");
        _;
    }

    modifier requireRandomValue() {
        require(randomValue[index] != 0);
        _;
    }

    /**
    * @notice Can it create a sending rule
    * @param _ratio Sending Rule ratio
    * @param _sendingCount SendingRule sending count
    */
    modifier canCreateSendingRule(uint _ratio, uint _sendingCount) {
        uint totalAmount = randomSendingRuleRatioTotalAmount + definitelySendingRuleRatioTotalAmount + (ratioAmount(_ratio) * _sendingCount);
        require(
            totalAmount < baseTokenAmount, 
            "TimedRandomSendContract: Only less than 100%"
        );
        _;
    }

    function randomSendingRuleIdsAll() public view returns(uint[] memory) {
        return randomSendingRuleIds;
    }

    function definitelySendingRuleIdsAll() public view returns(uint[] memory) {
        return definitelySendingRuleIds;
    }

    function ticketIdFromTicketIds(uint _ticketIdsIndex) internal view returns(uint) {
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

    function lastDefinitelySendingRuleIds() internal view returns(uint) {
        if (definitelySendingRuleIds.length == 0) {
            return 0;
        }
        return definitelySendingRuleIds[definitelySendingRuleIds.length - 1];
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
    function statusToAccepting(uint _closeTimestamp) public onlyOwner onlyByStatus(Status.DONE) {
        require(_closeTimestamp > block.timestamp, "closeTimestamp require after block.timestamp");
        closeTimestamp = _closeTimestamp;
        status = Status.ACCEPTING;
    }

    // TODO: chainlink vrfからのデータの取得を失敗する可能性があることを考慮する
    // リスク回避の方法としては、長時間vrfからの応答がなければ、受け取った費用を戻すようにする
    // しかし、費用を戻すのであれば、sellercommitionの送金はbuyticket時にしない方が良い
    function statusToRandomValueGetting() public onlyByStatus(Status.ACCEPTING) {
        require(closeTimestamp < block.timestamp, "after closeTimestamp");
        status = Status.RANDOM_VALUE_GETTING;
        totalSupplyByIndex[index] = totalSupply();
        requestRandomWords();
    }

    function statusToTokenSending() private {
        tokenSengingStatus = TokenSengingStatus.SEND_TO_SELLER;
        status = Status.TOKEN_SENDING;
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
        sendToSellerIndex++;
    }

    function tokenSengingStatusToRandomSend() public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.SEND_TO_SELLER) {
        require(_sellers[index][sendToSellerIndex] == address(0)); // 全ての送金が完了していること
        sendToSellerIndex = 0;
        tokenSengingStatus = TokenSengingStatus.RANDOM_SEND;
    }

    function convertRandomValueToTicketId(uint number) private view returns (uint) {
        return uint(keccak256(abi.encode(number))) % _ticketLastNumber[index][_ticketLastId[index]];
    }

    function randomSend(uint _ticketId) public onlyByStatus(Status.TOKEN_SENDING) onlyByTokenSendingStatus(TokenSengingStatus.RANDOM_SEND) {
        uint winnerTicketLastNumber = convertRandomValueToTicketId(currentRandomSendingRuleSendingCount + randomValue[index] + currentRandomSendingRuleIndex);
        // TODO: winnerTicketLastNumberが0になる可能性があるので、その時の当選者がいなくなってしまう
        
        // この間に乱数があれば、当選とみなす
        require(_ticketLastNumber[index][_ticketId - 1] <= winnerTicketLastNumber && (_ticketLastNumber[index][_ticketId - 1] + _ticketCount[index][_ticketId]) >= winnerTicketLastNumber);

        uint tokenAmount = totalSupplyByIndex[index].div(randomSendingRuleRatio[randomSendingRuleIds[currentRandomSendingRuleIndex]]);
        erc20.transfer(_ticketHolder[index][_ticketId], tokenAmount);
        
        nextToRandomSend();
    }

    function nextToRandomSend() private {
        // sending_countの人数分の送金が完了したら、次のrandon sending ruleにいく、
        if (currentRandomSendingRuleSendingCount == randomSendingRuleSendingCount[currentRandomSendingRuleIndex]) {
            if (currentRandomSendingRuleIndex == randomSendingRuleIds.length) {
                // randam sendは終了
                tokenSengingStatus = TokenSengingStatus.DEFINITELY_SEND;
                currentRandomSendingRuleIndex = 0;
                currentRandomSendingRuleSendingCount = 1;
            } else {
                 // currentRandomSendingRuleIndexをプラス１する
                currentRandomSendingRuleIndex++;
                currentRandomSendingRuleSendingCount = 1;
            }
        } else {
            // 次のsending countへ移る
            // 引数で_ticketIdをとるが、スマートコントラクトで承認する処理は必要になる, スマートコントラクトの処理の負荷を下げるためにこの処理をする
            currentRandomSendingRuleSendingCount++;
        }
    }
}
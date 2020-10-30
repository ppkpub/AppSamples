/****************************
 OdinMarketDao Demo Contract
       v0.27 2020-09-12
****************************/
pragma solidity ^0.6.2;

pragma experimental ABIEncoderV2;

interface OracleODIN {
    function getOdinRegisterBtcAddress(uint shortOdin ) external view
            returns ( string memory theOdinRegister);
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract OdinMarketDao {
    //相关合约参数
    address _projectDaoTokenContractAddress=0xBD5C1b5900B8106192214f8E08Ae8D8dDfB08210;//指定项目治理TOKEN合约地址
    address _oracleOdinContractAddress=0x5aCBBF15a27c8f93d4D0F48243F538FF05A4478a;  //ODIN号信息预言机
    
    // 订单状态枚举类型
    enum State { Created, Locked, Success,Inactive,Voting, VotedForSeller, VotedForBuyer }
  
    //声明一个结构类型，它代表一个奥丁号交易信息，包括价格、卖家、买家、状态等变量 
    struct OdinMarket {
        uint shortOdin;
        
        address payable  seller;
        uint256 initPriceWei; // 卖家初始报价和抵押金额，1200000000000000 WEI = 0.0012 ETHER
        
        address payable  buyer;
        uint256 bidWei; //买家出价和抵押金额
        
        string  destBuyerBtcAddress; //买家指定接收奥丁号的BTC地址
        
        State state;
        
        //uint lastBlock;   // 新建或最后更新区块号
    }
    
    // 声明一个变量来存储交易列表
    mapping( uint => OdinMarket ) private _marketList;
    uint  _lastMarketSN; //流水编号
    
    // 声明一个变量来存储仲裁投票中的交易列表
    struct VoteRecord {
        uint counter_for_seller;
        uint counter_for_buyer;
        
        uint[] votes;  //数组元素对应投票人ID排列，取值为投票选择值(0 未投,5支持卖家，6支持买家)
    }
    
    mapping( uint => VoteRecord ) public _votingMarkets;
    
    //投票者处理纠纷的奖金占交易初始抵押金的比例
    uint8 _bonusVoterPercent = 30; 
    
    //买卖纠纷仲裁者数组
    mapping( address => uint256 ) private _voters;  
    uint  public _lastVoterID=0;
    
    //投票人参与投票获得奖金
    mapping( uint => uint256 ) private _voterBonusEthBalanceWeis;  
    
    //DAO启动所需最少仲裁投票人数
    uint  public _minVoterNum=3;  //正式版本可以调到21
    
    //成为仲裁投票人所需支持启动资金
    uint256  _minVoterDonateEthWei=0.1 ether;  //正式版本可以调到1 ether

    //启动SWAP兑换池的标志
    bool public _poolStarted=false;

    //自动做市机制的初始KEY值
    uint256 _swapAmmKey;
    
    //缺省自动购买抵押ETH金额对应百分比的项目治理代币
    uint8 _autoSwapDaoTokenPercent = 10; 
    
    //报价上限（对初始抵押卖价的涨幅）
    //uint8 _bidPriceLimit = 10; 


    //合约保存的全部ETH资金
    uint256  public _totalEthBalanceWei;  
    
    //兑换池中的ETH余额
    uint256  public _poolEthBalanceWei; 
    
    //兑换池中的项目治理Token余额
    uint256  public _poolTokenBalance; 
    
    //用户可用的ETH资金
    mapping( address => uint256 ) private _userEthBalanceWeis;  
    
    //用户抵押买卖锁定的ETH资金
    mapping( address => uint256 ) private _userLockedEthBalanceWeis;  

    // 定义构造函数，初始化参数信息
    constructor () public  {
        _lastMarketSN = 0 ; 
        
        _lastVoterID = 1;
        _voters[msg.sender] = _lastVoterID ;
    }
    
    //支持资金成为投票者
    function  donateToBeVoter( uint256 donate_eth_wei ) external
    {
        require(
               ! _poolStarted ,
                "DAO had been started!"
        );
        
        if( donate_eth_wei < _minVoterDonateEthWei)
           revert("Donate not enough to be a voter");
        
        if( donate_eth_wei > _userEthBalanceWeis[msg.sender])
           revert("Balance not enough");
            
        if( _voters[msg.sender]>0 )
           revert("Already been a voter");
           
        _lastVoterID ++;
        _voters[msg.sender] = _lastVoterID ;

        _userEthBalanceWeis[msg.sender] -= donate_eth_wei;
        _poolEthBalanceWei += donate_eth_wei ;
        
        if(_lastVoterID >= _minVoterNum){
            activeMarketDAO();
        }
    }
    
    //更新投票者地址
    function  updateVoterAddress( address new_address ) external
    {
        uint voter_id = _voters[msg.sender];
        if(voter_id==0)
            revert( "Not voter" );
        
        delete _voters[msg.sender];
        
        _voters[new_address] = voter_id ;
    }
    
    
    //激活DAO, 抵押拍卖开市，开启自动做市兑换池
    function  activeMarketDAO( ) private
    {
        IERC20 tmp_contract =  IERC20(_projectDaoTokenContractAddress);

        _poolTokenBalance = tmp_contract.balanceOf(address(this));
        
        if(_poolTokenBalance>0 && _poolEthBalanceWei>0 ){
                
            _swapAmmKey = _poolTokenBalance * _poolEthBalanceWei;
                
            _poolStarted = true;
        }
    }
    
    
    //人工激活DAO, 抵押拍卖开市，开启自动做市兑换池
    function  manualActiveMarketDAO( ) external
       returns ( uint256 eth_balance_wei , uint token_balance)
    {
        require(
               ! _poolStarted ,
                "DAO had been started!"
        );
        require(
               _lastVoterID >= _minVoterNum ,
                "Need more voters to start the DAO!"
        );
        
        activeMarketDAO();
        
        eth_balance_wei = _poolEthBalanceWei;
        token_balance = _poolTokenBalance;
    }
    
    //锁定抵押资金和自动兑换项目治理token
    function  lockAndSwap( address user, uint256 charge_wei) private
    {
        uint256 valid_eth_wei = _userEthBalanceWeis[user];
        if( valid_eth_wei<charge_wei ){
            revert("User balance not enough");
        }
        
        uint256 auto_swap_eth_wei = charge_wei * _autoSwapDaoTokenPercent / 100;
        uint256 lock_eth_wei = charge_wei - auto_swap_eth_wei;
        
        if( auto_swap_eth_wei == 0 ){
            revert("No enough amount"); //不够自动兑换
        }
        
        _userLockedEthBalanceWeis[user] += lock_eth_wei ;
        _userEthBalanceWeis[user] = valid_eth_wei - charge_wei;
        
        uint256 swapped_token_amount = countSwappableToken(auto_swap_eth_wei) ;
        
        if(swapped_token_amount>0){
            _poolTokenBalance -= swapped_token_amount;
            sendPojectToken(msg.sender,swapped_token_amount);
        }
        
        _poolEthBalanceWei += auto_swap_eth_wei;

    }
    
    function countSwappableToken( uint256 sell_eth_wei ) public view
            returns ( uint swapped_token_amount)
    {
        uint256 new_fund_eth_balance_wei = _poolEthBalanceWei + sell_eth_wei;
        
        swapped_token_amount = _poolTokenBalance - _swapAmmKey/new_fund_eth_balance_wei ;
    }
    
    //用项目token换ETH
    function  swapProjectTokenToETH(  uint256 sell_token_amount,bool keep_in_contract_balance) external
    {
        require( sell_token_amount>0 );
        
        IERC20 tmp_contract =  IERC20(_projectDaoTokenContractAddress);

        if(!tmp_contract.transferFrom(msg.sender,address(this), sell_token_amount))
            revert("No enough token");
        
        uint256 swapped_eth_wei = countSwappableETH(sell_token_amount) ;
        if( swapped_eth_wei == 0 ){
            revert("No enough eth in pool"); //不够自动兑换
        }
        
        _poolTokenBalance += sell_token_amount;
        _poolEthBalanceWei -= swapped_eth_wei;

        if(keep_in_contract_balance){
            //存入用户的市场账户
            _userEthBalanceWeis[msg.sender] += swapped_eth_wei;
        }else{
            //转出到用户钱包
            _totalEthBalanceWei -= swapped_eth_wei;
            msg.sender.transfer(swapped_eth_wei);
        }
        
    }
    
    function countSwappableETH( uint256 sell_token_amount ) public view
            returns ( uint swapped_eth_wei)
    {
        uint256 new_fund_token_balance = _poolTokenBalance + sell_token_amount;
        
        swapped_eth_wei = _poolEthBalanceWei - _swapAmmKey/new_fund_token_balance ;
    }
   

    // 订单状态变化时调用的事件函数
    event newBid(uint market_id);
    event bidAccepted(uint market_id);
    event bidAborted(uint market_id);
    event bidVoting(uint market_id);
    event itemReceived(uint market_id);
    event inactive(uint market_id);
  
  
    // 卖家抵押发起拍卖单，ETH将被暂时锁定，并自动购买一些治理token
    function  createMarket( uint short_odin, uint256 price_wei) public
       returns ( uint new_market_id)
    {
        require(
               _poolStarted ,
                "SwapFund not started!"
        );
        require(
               short_odin>0 && price_wei > 0 ,
                "short_odin or price invalid."
        );

        lockAndSwap(msg.sender,price_wei);

        _lastMarketSN ++ ;
        _marketList[_lastMarketSN] = OdinMarket({
            shortOdin : short_odin,
            
            seller : msg.sender,
            initPriceWei : price_wei,
            
            buyer :address(0),
            bidWei : 0 ,
            destBuyerBtcAddress :"",
            
            state: State.Created
        });
        
        new_market_id = _lastMarketSN;
    }
        
    
    //从合约兑换池中发送自动兑换的项目治理Token
    function sendPojectToken(address user, uint amount ) private
    {
        require( amount>0 );

        IERC20 tmp_contract =  IERC20(_projectDaoTokenContractAddress);

        if(!tmp_contract.transfer(user, amount))
            revert();

    }

    
    //买家确认购买，以太币将被暂时锁定，直到确认收货。
    function createBid( uint market_id , uint256 bid_wei, string memory dest_register_btc_address ) public
    {
        require(
               _poolStarted ,
                "SwapFund not started!"
        );
        
        OdinMarket memory market = _marketList[market_id];
        if( market.seller==address(0) ){
            revert("Not existed market");
        }
        
        if( market.seller==msg.sender ){
            revert("Can't bid yourself");
        }
        
        if( market.state!=State.Created ){
            revert("Locked or inactive  market");
        }
        
        if(bid_wei <= market.bidWei || bid_wei< market.initPriceWei ){
            revert("Your bid amount too lower");
        }
        
        lockAndSwap(msg.sender,bid_wei);
        
        address old_buyer = market.buyer ;
        if(old_buyer!=address(0)){//退款已有的买家
            uint256 refund_wei =  market.bidWei *(100-_autoSwapDaoTokenPercent)/100;
            
            _userLockedEthBalanceWeis[old_buyer] -= refund_wei ;
            _userEthBalanceWeis[old_buyer] += refund_wei;
        }
        
        market.buyer = msg.sender;
        market.bidWei = bid_wei;
        market.destBuyerBtcAddress = dest_register_btc_address;

         _marketList[market_id] = market;
         
         emit newBid(market_id);
    }
    
    //卖家确认接受报价
    //订单状态变为锁定
    function acceptLastBid(uint market_id ) external  
    {
        require(
               _poolStarted ,
                "SwapFund not started!"
        );
        
        OdinMarket memory market = _marketList[market_id];
        
        if( market.seller != msg.sender  ){
            revert("Only the seller can accept bid");
        }
        
        if( market.buyer==address(0) ){
            revert("No valid bid");
        }
        
        if( market.state!=State.Created ){
            revert("Locked or inactive  market");
        }

        market.state = State.Locked;
        _marketList[market_id] = market;
        
         emit bidAccepted(market_id);
    }
    
    // 买家主动确认收货，锁定的以太币将被发送给卖家
    // 或者卖家发起主动提款，在通过预言机验证后, 锁定的以太币也将被发送给卖家。
    // 订单状态变为完成
    function confirmReceived( uint market_id ) external  
    {
        require(
               _poolStarted ,
                "SwapFund not started!"
        );
        
        OdinMarket memory market = _marketList[market_id];
        if( market.seller==address(0) ){
            revert("Not existed market");
        }
        
        if( msg.sender == market.buyer ){
            if( market.state!=State.Locked  && market.state!=State.Voting ){
                revert("The bid is not accepted");
            }
        }else if( msg.sender == market.seller   ){
            if( market.state!=State.Created && market.state!=State.Locked  && market.state!=State.Voting ){
                revert("The market is inactive");
            }

            //调用oracle合约查询奥丁号的状态
            OracleODIN oracleODIN = OracleODIN(_oracleOdinContractAddress);
            string memory odin_register_btc_address = oracleODIN.getOdinRegisterBtcAddress(market.shortOdin); 
            bytes memory b1 =  bytes(odin_register_btc_address);
            bytes memory b2 =  bytes(market.destBuyerBtcAddress);

            if(  b1.length != b2.length 
                 || keccak256( b1 ) != keccak256( b2 )  ){
                revert("The ODIN register mismatched "); //状态不符，说明奥丁号尚未在比特币链上过户完成
            }
        }else{
            revert("Only the seller/buyer can confirm that the ODIN be transfered" );
        }

        uint256 trans_wei =  market.bidWei *(100-_autoSwapDaoTokenPercent)/100;
        uint256 refund_wei =  market.initPriceWei *(100-_autoSwapDaoTokenPercent)/100;
        
        _userLockedEthBalanceWeis[market.buyer] -= trans_wei ;
        _userLockedEthBalanceWeis[market.seller] -= refund_wei ;
        _userEthBalanceWeis[market.seller] += refund_wei+trans_wei;
        
        market.state = State.Success;
        _marketList[market_id] = market;
        
        emit itemReceived(market_id);
    }
    
    //卖家可以终止卖单并退回买卖双方抵押的以太币
    function abortMarket( uint market_id ) external
    {
        require(
               _poolStarted ,
                "SwapFund not started!"
        );
        
        OdinMarket memory market = _marketList[market_id];
        if( market.seller==address(0) ){
            revert("Not existed market");
        }
        
        if( msg.sender != market.seller   ){
            revert("Only the seller can abort the market" );
        }
        
        
        if( market.state==State.VotedForSeller ){ 
            //出现买卖纠纷状态后卖家获得支持,买家资金扣除给投票者的奖励后支付给卖家
            uint256 charge_buyer_wei =  market.bidWei *(100-_autoSwapDaoTokenPercent)/100;
            
            _userLockedEthBalanceWeis[market.buyer] -= charge_buyer_wei ;
            
            
            uint256 refund_seller_wei =  market.initPriceWei *(100-_autoSwapDaoTokenPercent)/100;
            _userLockedEthBalanceWeis[market.seller] -= refund_seller_wei ;
            
            VoteRecord memory vote_record = _votingMarkets[market_id];
            
            uint256 bonus_voter_wei =  (refund_seller_wei*_bonusVoterPercent/100)/vote_record.counter_for_seller;
            
            uint256 bonus_total_wei =0;
            for(uint i = 0; i < vote_record.votes.length; i++) {
                if(vote_record.votes[i]==5){
                    _voterBonusEthBalanceWeis[i+1] += bonus_voter_wei;
                    bonus_total_wei += bonus_voter_wei;
                }
            }

            _userEthBalanceWeis[market.seller] +=   charge_buyer_wei + refund_seller_wei - bonus_total_wei ;

            market.state = State.Inactive;
            _marketList[market_id] = market;
            
            emit inactive(market_id);
        }else if( market.state==State.Created || market.state==State.Locked || market.state==State.Voting  ){
            //注意：在出现纠纷正投票时，卖家仍可以主动取消交易并退款
            if(market.buyer!=address(0)){
                uint256 refund_buyer_wei =  market.bidWei *(100-_autoSwapDaoTokenPercent)/100;
                
                _userLockedEthBalanceWeis[market.buyer] -= refund_buyer_wei ;
                _userEthBalanceWeis[market.buyer] += refund_buyer_wei;
            }
            
            uint256 refund_seller_wei =  market.initPriceWei *(100-_autoSwapDaoTokenPercent)/100;
            _userLockedEthBalanceWeis[market.seller] -= refund_seller_wei ;
            _userEthBalanceWeis[market.seller] += refund_seller_wei;

            market.state = State.Inactive;
            _marketList[market_id] = market;
            
            emit inactive(market_id);
        }else{
            revert("The market is inactive");
        }
    }
    
    //买家可以取消报价,拿回抵押的以太币
    function abortBid( uint market_id ) external
    {
        require(
               _poolStarted ,
                "SwapFund not started!"
        );
        
        OdinMarket memory market = _marketList[market_id];
        if( market.seller==address(0) ){
            revert("Not existed market");
        }
        
        if( msg.sender != market.buyer   ){
            revert("Only the buyer can abort the bid" );
        }
        
        if( market.state==State.Created  ){
            uint256 refund_wei =  market.bidWei *(100-_autoSwapDaoTokenPercent)/100;
            
            _userLockedEthBalanceWeis[market.buyer] -= refund_wei ;
            _userEthBalanceWeis[market.buyer] += refund_wei;
            
            market.state = State.Created;
            market.buyer=address(0);
            market.bidWei=0;
            market.destBuyerBtcAddress="";
            _marketList[market_id] = market;
            
            emit bidAborted(market_id);
        }else  if( market.state==State.Locked  ){
            //已锁定的买卖，可能存在卖家已发货，需要投票仲裁
            market.state = State.Voting;
            _marketList[market_id] = market;
            
            //生成一个投票记录数据
            _votingMarkets[market_id]=VoteRecord({
                counter_for_seller:0,
                counter_for_buyer:0,
                
                votes: new uint[](_lastVoterID)   
            });

            emit bidVoting(market_id);
        }else  if( market.state==State.VotedForBuyer  ){
            //经过投票, 买家拿到退款，同时扣罚卖家抵押金，一部分给与结果一致投票者平分，剩下给买家
            uint256 charge_seller_wei =  market.initPriceWei *(100-_autoSwapDaoTokenPercent)/100;
            _userLockedEthBalanceWeis[market.seller] -= charge_seller_wei ;
            
            VoteRecord memory vote_record = _votingMarkets[market_id];
            
            uint256 bonus_voter_wei =  (charge_seller_wei*_bonusVoterPercent/100)/vote_record.counter_for_buyer;
            
            uint256 bonus_total_wei =0;
            for(uint i = 0; i < vote_record.votes.length; i++) {
                if(vote_record.votes[i]==6){
                    _voterBonusEthBalanceWeis[i+1] += bonus_voter_wei;
                    bonus_total_wei += bonus_voter_wei;
                }
            }
            
            uint256 refund_buyer_wei =  market.bidWei *(100-_autoSwapDaoTokenPercent)/100;
            _userLockedEthBalanceWeis[market.buyer] -= refund_buyer_wei ;
            _userEthBalanceWeis[market.buyer] += refund_buyer_wei + charge_seller_wei - bonus_total_wei;       

            market.state = State.Inactive;
            _marketList[market_id] = market;
            emit inactive(market_id);
        }else{
            revert("The market is inactive");
        }

        

    }
    
    //投票仲裁
    // vote_choice ： 0 弃权 5 支持卖家  6 支持买家
    function  voteBid( uint market_id,uint vote_choice ) external
    {
        require(
               _poolStarted ,
                "SwapFund not started!"
        );
        
        uint voter_id = _voters[msg.sender];
        if(voter_id==0)
            revert( "Not voter" );

        OdinMarket memory market = _marketList[market_id];
        if( market.seller==address(0) ){
            revert("Not existed market");
        }

        if( market.state!=State.Voting ){ //不是投票中
            revert("The market is not voting");
        }
        
        VoteRecord memory vote_record = _votingMarkets[market_id];
            
        if(vote_record.votes[voter_id-1]==5)
            vote_record.counter_for_seller--;
        else if(vote_record.votes[voter_id-1]==6)
            vote_record.counter_for_buyer--;
                    
        if(vote_choice==5)
            vote_record.counter_for_seller++;
        else if(vote_choice==6)
            vote_record.counter_for_buyer++;
            
        vote_record.votes[voter_id-1]=vote_choice;
        
        _votingMarkets[market_id] = vote_record ;
        
        
        if(vote_record.counter_for_buyer >_lastVoterID/2){ //支持买家超过半数
            market.state = State.VotedForBuyer;
            _marketList[market_id] = market;
        }else if(vote_record.counter_for_seller >_lastVoterID/2){ //支持卖家超过半数
            market.state = State.VotedForSeller;
            _marketList[market_id] = market;
        }
    }
    
    /*
    function deleteArrayValue(uint[] memory dest_array,uint val) public pure returns ( uint[] memory) {
        for(uint i = 0; i < dest_array.length; i++) {
            if(dest_array[i]==val){
                delete(dest_array[i]);
                return dest_array;
            }
        }
        
    }
    */
    
    function getVoteInfo( uint market_id ) public view returns ( VoteRecord memory ) {
        return _votingMarkets[market_id];
    }
    
    
    function getVoteCounter( uint market_id ) public view returns ( uint counter_for_seller,uint counter_for_buyer ) {
        VoteRecord memory vote_record = _votingMarkets[market_id];
        
        counter_for_seller = vote_record.counter_for_seller;
        counter_for_buyer = vote_record.counter_for_buyer;
    }
    
    
    function getVoterID( address user ) public view returns ( uint ) {
        return _voters[user];
    }

    // 当交易没有数据或者数据不对时，触发此函数，
    // 按充值操作处理，确保买家不会丢失资金
    fallback()  payable external  
    {
        require( msg.value >0 );
        
        _userEthBalanceWeis[msg.sender]=_userEthBalanceWeis[msg.sender]+msg.value;

        _totalEthBalanceWei += msg.value ;
    }
    
  
    function getUserBalance( address user ) public view
            returns ( uint valid_eth_wei,uint  locked_eth_wei , uint voter_bonus_wei )
    {
        valid_eth_wei = _userEthBalanceWeis[user];
        locked_eth_wei = _userLockedEthBalanceWeis[user];
        voter_bonus_wei = _voterBonusEthBalanceWeis[ _voters[user]  ];
    }
    
    
    function getMarket( uint market_id ) public view
            returns ( OdinMarket memory market)
    {
        market = _marketList[market_id];
    }
    
    function getLastMarketID(  ) public view
            returns ( uint market_id)
    {
        market_id = _lastMarketSN;
    }
    
    //用户安全提取ETH资金
    function  withdrawETH( uint amount ) external
    {
        require( amount>0 );

        uint256 valid_eth_wei = _userEthBalanceWeis[msg.sender];
        if( valid_eth_wei<amount ){
            revert("User balance not enough");
        }
        
        _userEthBalanceWeis[msg.sender] -= amount;
        _totalEthBalanceWei -= amount;
        
        msg.sender.transfer(amount);
    }
    
    //投票人安全提取ETH奖金
    function  voterWithdrawBonus( uint amount ) external
    {
        require( amount>0 );

        uint voter_id = _voters[msg.sender];
        if(voter_id==0)
            revert( "Not voter" );
            
        uint256 valid_bonus_wei = _voterBonusEthBalanceWeis[ voter_id ];
        if( valid_bonus_wei<amount ){
            revert("Voter bonus balance not enough");
        }
        
        _voterBonusEthBalanceWeis[ voter_id ] -= amount;
        _totalEthBalanceWei -= amount;
        
        msg.sender.transfer(amount);
    }
}
    //only for test
    address public tester_seller= 0xdc58e70fd42c2494559F01cF4320E1213de65d26;
    address public tester_buyer= 0xFf42Db740D5fAc23cAc414DfED12308715D11988;
    
    function test1_deployer_init_dao() external{
        require(
               !_poolStarted ,
                "DAO started!"
        );
        
        require(
               _totalEthBalanceWei >=0.2 ether  ,
                "Eth balance not enough!"
        );
        
        _poolEthBalanceWei = 0.1 ether;

        _lastVoterID ++;
        _voters[tester_seller] = _lastVoterID ;
        _userEthBalanceWeis[tester_seller]=0.01 ether;
        
        _lastVoterID ++;
        _voters[tester_buyer] = _lastVoterID ;
        _userEthBalanceWeis[tester_buyer]=0.015 ether;
        
        activeMarketDAO();
    }
    
    function test2_seller_add_markets() external{
        require(
               _poolStarted ,
                "DAO not started!"
        );
        require(
               msg.sender == tester_seller ,
                "Not test seller!"
        );
        createMarket(  111 , 0.002 ether);
        //createMarket(  222 , 0.003 ether);
    }
    
    function test3_buyer_add_bids() external{
        require(
               _poolStarted ,
                "DAO not started!"
        );
        
        require(
               msg.sender == tester_buyer ,
                "Not test buyer!"
        );
        
        createBid( 1 ,  0.003 ether, "1test" );
        //createBid( 2 ,  0.005 ether, "1test" );
    }
    
    //在测试时转移ETH资金
    function  testWithdrawETH( uint amount ) external
    {
        require( amount>0  && _voters[msg.sender]>0 );
        
        msg.sender.transfer(amount);
    }
    
    //在测试时转移Token资金
    function  testWithdrawToken( uint amount ) external
    {
        require( amount>0  && _voters[msg.sender]>0 );
        
        sendPojectToken( msg.sender,amount);
    }
    
    //end of test cases
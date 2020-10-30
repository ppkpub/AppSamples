pragma solidity ^0.5.0;

import "./Context.sol";
import "./ERC20.sol";
import "./ERC20Detailed.sol";

/**
 * @dev Interface of deposit token to Fund Contract.
 */
interface TokenFundContract {
    function deposited(address depositer, uint256 amount) external returns (bool);
}

contract MyTestToken is Context, ERC20, ERC20Detailed {
    address private chairperson; //有权更新的地址
    address private _contractAuctionAddress;
    
    //MyTestToken： 代币的全名
    //ZPC：代币的简写
    //3: 代币小数点位数，代币的最小单位， 0表示没有小数
    constructor () public ERC20Detailed("MyTestToken", "MTT", 0) {
        //初始化币，并把所有的币都给部署智能合约的ETH钱包地址
        //100000000：代币的总数量
        _mint(_msgSender(), 100000000 * (10 ** uint256(decimals())));
        
        chairperson = msg.sender;
    }
    
    //登记关联的基金合约
    function updateFund(address new_contract) public {
        require( msg.sender == chairperson );
        _contractAuctionAddress = new_contract;
    }
    
    //充值Token到指定合约
    function depositFund( uint amount ) public
    {
        require( amount>0 );
        require( _contractAuctionAddress != address(0)  );
        
        TokenFundContract tmp_contract =  TokenFundContract(_contractAuctionAddress);

        if(!_transfer(msg.sender,_contractAuctionAddress, amount))
            revert();

            
        if(!tmp_contract.deposited(msg.sender,  amount))
            revert();
        
    }
}
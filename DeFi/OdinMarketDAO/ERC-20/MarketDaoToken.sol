pragma solidity ^0.5.0;

import "./Context.sol";
import "./ERC20.sol";
import "./ERC20Detailed.sol";

contract MarketDaoToken is Context, ERC20, ERC20Detailed {
    //MarketDaoToken： 代币的全名
    //MDT1：代币的简写
    //0: 代币小数点位数，代币的最小单位， 0表示没有小数
    constructor () public ERC20Detailed("MarketDaoToken1", "MDT1", 0) {
        //初始化币，并把所有的币都给部署智能合约的ETH钱包地址
        //100000000：代币的总数量
        _mint(_msgSender(), 100000000 * (10 ** uint256(decimals())));
    }

}
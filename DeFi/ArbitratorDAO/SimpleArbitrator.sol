/**
 * @authors: [@ferittuncer, @hbarcelos, @ppkpub]
 * @reviewers: []
 * @auditors: []
 * @bounties: []
 * @deployments: []
 * SPDX-License-Identifier: MIT
 * 2020-11-01
 */
pragma solidity >=0.7;

pragma experimental ABIEncoderV2;

import "IArbitrator.sol";
import "IArbitrator.sol";

/**
 * Copyright 2018 ZeroEx Intl.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *   http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/**
 * Utility library of inline functions on addresses
 */
library Address {

  /**
   * Returns whether the target address is a contract
   * @dev This function will return false if invoked during the constructor of a contract,
   * as the code is not actually created until after the constructor finishes.
   * @param account address of the account to check
   * @return whether the target address is a contract
   */
  function isContract(address account) internal view returns (bool) {
    bytes32 codehash;
    bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    // XXX Currently there is no better way to check if there is a contract in an address
    // than to check the size of the code at that address.
    // See https://ethereum.stackexchange.com/a/14016/36603
    // for more details about how this works.
    // TODO Check this again before the Serenity release, because all addresses will be
    // contracts then.
    assembly { codehash := extcodehash(account) }
    return (codehash != 0x0 && codehash != accountHash);
  }

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

contract SimpleArbitrator is IArbitrator {
    address public owner = msg.sender;
    
    //Arbitrator DAO TOKEN
    address arbitratorTokenContractAddress=0x7fc68c65500e8C14fd7b301F2c5CE8f4eD5E80B4;
    
    //陪审团人数
    uint constant  JURY_MEMBER_NUM = 3;
    
    //最少仲裁费用
    uint constant  MIN_ARBITRATION_COST = 0.1 ether;
    
    //注册成为仲裁投票者要求的最少持有ArbitratorToken数
    uint constant  MIN_ARBITRATOR_TOKEN_AMOUNT_FOR_VOTER = 0;
    
    //注册投票人编号起始值
    uint constant  VOTER_SN_START = 10001;

    struct Dispute {
        IArbitrable arbitrated;
        uint256 choices;
        uint256 ruling;
        DisputeStatus status;
        
        uint256 arbitrationFee;
        
        //陪审团的成员人数
        uint jurorNum;
        
        //仲裁者ID数组
        uint[] jurorSNs; 
        
        //仲裁者投票记录数组
        uint256[] jurorChoices; 

        //对应choices取值排列的数组
        uint[] choiceVoteCounters; 
        
        bytes extraData;
    } 
    
    struct VoterInfo {
        //uint    voterSN;  
        address voterAddress;
        bytes   voterURI; 
        uint    voterBonusWei;
    }
    
    //注册仲裁投票者数组
    mapping( address => uint ) private       mapVoterAddressToSN;  
    VoterInfo[] private                      registeredVoterList;
    uint                                     lastSelectedVoterSN;

    Dispute[] public disputes;
    
    //累积奖励池
    uint256 public daoSharedBonusWei;
    
    
    // 定义构造函数，初始化参数信息
    constructor ()  {
        lastSelectedVoterSN = 0  ;
        daoSharedBonusWei = 0;
    }
    
    
    //注册成为投票者
    function  registerVoter( bytes memory _your_uri  ) external returns (uint)
    {
        require( getVoterSN(msg.sender)  == 0, 
                 "Existed voter.");
                 
        require( !Address.isContract(msg.sender) , 
                 "Only normal address could be voter.");         
        
                 
        require( IERC20(arbitratorTokenContractAddress).balanceOf(msg.sender)  >= MIN_ARBITRATOR_TOKEN_AMOUNT_FOR_VOTER, 
                 "Not enough TOKEN to become a voter.");
        
        //注意：第一个注册的voterSN为参数VOTER_SN_START，后续依次累加生成
        uint  new_voter_sn = VOTER_SN_START+registeredVoterList.length;
        registeredVoterList.push(  VoterInfo({  voterAddress:msg.sender , voterURI:_your_uri, voterBonusWei:0 }) ) ;
        mapVoterAddressToSN[msg.sender] =new_voter_sn;
        
        return new_voter_sn;
    }
    
    //更新投票者信息
    function  updateVoterInfo(address _new_address , bytes memory _new_uri  ) external 
    {
        uint voter_sn = getVoterSN(msg.sender);
        require( voter_sn  > 0, 
                 "Not existed voter.");
        
        if(_new_address!=msg.sender){
            require( getVoterSN( _new_address )  == 0, 
                 "Existed voter for the new address.");
            require( !Address.isContract(_new_address) , 
                 "Only normal address could be voter.");

            delete  mapVoterAddressToSN[ msg.sender ] ;

            mapVoterAddressToSN[_new_address] = voter_sn;        
        }

        VoterInfo memory  voter_info = registeredVoterList[voter_sn-VOTER_SN_START];
        voter_info.voterAddress = _new_address;
        voter_info.voterURI = _new_uri;
        
        registeredVoterList[voter_sn-VOTER_SN_START] = voter_info;
    }
    
    function getVoterSN( address   _voter_address  ) public view 
    returns ( uint ) 
    {
        return mapVoterAddressToSN[_voter_address];
    }
    
    function getVoterInfo( address   _voter_address  ) public view 
    returns ( uint voterSN,  bytes memory voterURI,uint256 voterBonusWei) 
    {
        voterSN = mapVoterAddressToSN[_voter_address];
        if(voterSN>0){
              (,voterURI,voterBonusWei)=getVoterInfo(voterSN);
        }
    }
    
    function getVoterInfo( uint   _voter_sn  ) public view 
    returns ( address voterAddress,bytes memory voterURI,uint256 voterBonusWei) 
    {
        
        require(  _voter_sn>0  &&  _voter_sn-VOTER_SN_START<registeredVoterList.length, 
                 "Not xisted voter.");
                 
        VoterInfo memory  voter_info = registeredVoterList[_voter_sn-VOTER_SN_START];
        voterAddress= voter_info.voterAddress;
        voterURI = voter_info.voterURI;
        voterBonusWei = voter_info.voterBonusWei;
    }
    
    function getDisputeInfo( uint dispute_id ) public view
            returns ( Dispute memory dispute_record)
    {
        dispute_record = disputes[dispute_id];
    }
    
    /*
    function fetchDisputeRecords( uint256 end_dispute_id, uint num ) public view
            returns ( uint record_num , uint[][] memory dispute_records)
    {
        dispute_records = new uint[][](0);
        record_num=0;
        for(uint256 dispute_id=end_dispute_id; dispute_id>=0 ; dispute_id--){
            dispute_records.push([1, 2, 3]);
        }
    }
    */
    
    function getStatusInfo(  ) public view
            returns ( uint voter_num, 
                      uint dispute_num, 
                      uint last_dispute_id, 
                      uint last_selected_voter_sn,
                      uint  dao_shared_bonus_wei , 
                      address project_token_contract_address )
    {
        voter_num = registeredVoterList.length;
        dispute_num = disputes.length;
        last_dispute_id = disputes.length - 1 ;
        last_selected_voter_sn = lastSelectedVoterSN;
        dao_shared_bonus_wei = daoSharedBonusWei;
        project_token_contract_address = arbitratorTokenContractAddress;
    }
    
    //分红,待实现
    function dividend() external
    {
    
    }
    
    //已注册投票人安全提取奖金
    function  voterWithdrawBonus( uint amount ) external
    {
        require( amount>0 );

        uint voter_sn = getVoterSN(msg.sender);
        
        require( voter_sn>0 ,  "Not registered voter");

        VoterInfo memory  voterInfo = registeredVoterList[voter_sn-VOTER_SN_START];
        require( voterInfo.voterBonusWei>=amount ,  "not enough voter bonus balance!");
        
        voterInfo.voterBonusWei -= amount;
        registeredVoterList[voter_sn-VOTER_SN_START] = voterInfo;
        
        msg.sender.transfer(amount);
    }

    //ERC792 implement
    function arbitrationCost(bytes memory _extraData) public override pure returns (uint256) {
        //uint256 offer_cost =  bytesToUint(_extraData);
        //return offer_cost>MIN_ARBITRATION_COST ? offer_cost : MIN_ARBITRATION_COST;
        
        return MIN_ARBITRATION_COST;
    }

    function appealCost(uint256 _disputeID, bytes memory _extraData) public override pure returns (uint256) {
        return 2**250; // An unaffordable amount which practically avoids appeals.
    }

    function createDispute(uint256 _choices, bytes memory _extraData)
        public
        override
        payable
        returns (uint256 disputeID)
    {
        require(msg.value >= arbitrationCost(_extraData), "Not enough ETH to cover arbitration costs.");
        require(registeredVoterList.length >= JURY_MEMBER_NUM, "Not enough registered voters.");


        uint[] memory juror_sns=new uint[](JURY_MEMBER_NUM); 
        uint256[] memory juror_choices=new uint256[](JURY_MEMBER_NUM); 
        uint[] memory choice_vote_counters=new uint[](JURY_MEMBER_NUM); 
        
        //选择若干voter构成新争议的陪审团
        uint juror_num = 0;
        uint checked_num = 0;
        address check_voter_address;
        while( true ){
            if(lastSelectedVoterSN-VOTER_SN_START+1>=registeredVoterList.length){
                //从头开始轮选
                lastSelectedVoterSN=VOTER_SN_START;
            }else{
                lastSelectedVoterSN++;
            }
            
            (check_voter_address,,)=getVoterInfo(lastSelectedVoterSN);
            
            if( IERC20(arbitratorTokenContractAddress).balanceOf( check_voter_address  ) 
                >= MIN_ARBITRATOR_TOKEN_AMOUNT_FOR_VOTER){
                //Not enough TOKEN to be a juror
                juror_sns[juror_num]=lastSelectedVoterSN;
                juror_choices[juror_num]=0;
                juror_num++;
                
                if(juror_num>=JURY_MEMBER_NUM)
                    break;
            }
            
            checked_num++;
            if(checked_num>=registeredVoterList.length){
                //已检查一圈
                revert("No enough valid voters!");
            }
        }
        
        disputes.push(  Dispute({
                arbitrated: IArbitrable(msg.sender),
                choices: _choices,
                ruling: uint256(-1),
                status: DisputeStatus.Waiting,
                arbitrationFee: msg.value,
                
                jurorNum:juror_num,
                jurorSNs:juror_sns,
                jurorChoices:juror_choices,
                choiceVoteCounters:choice_vote_counters,
                
                extraData : _extraData
            })  );

        disputeID = disputes.length - 1;
        emit DisputeCreation(disputeID, IArbitrable(msg.sender));
    }

    function disputeStatus(uint256 _disputeID) public override view returns (DisputeStatus status) {
        status = disputes[_disputeID].status;
    }

    function currentRuling(uint256 _disputeID) public override view returns (uint256 ruling) {
        ruling = disputes[_disputeID].ruling;
    }

    /*
    function rule(uint256 _disputeID, uint256 _ruling) public {
        require(msg.sender == owner, "Only the owner of this contract can execute rule function.");

        Dispute storage dispute = disputes[_disputeID];

        require(_ruling <= dispute.choices, "Ruling out of bounds!");
        require(dispute.status == DisputeStatus.Waiting, "Dispute is not awaiting arbitration.");

        dispute.ruling = _ruling;
        dispute.status = DisputeStatus.Solved;

        msg.sender.send(arbitrationCost(""));
        dispute.arbitrated.rule(_disputeID, _ruling);
    }
    */
    
    function rule(uint256 _disputeID, uint256 _ruling) public {
        //require(msg.sender == owner, "Only the owner of this contract can execute rule function.");
        
        uint voter_sn = getVoterSN(msg.sender);
        require(voter_sn >0 , "Not a registered voter.");

        Dispute storage dispute = disputes[_disputeID];

        require(_ruling <= dispute.choices, "Ruling out of bounds!");
        require(dispute.status == DisputeStatus.Waiting, "Dispute is not awaiting arbitration.");
        
        
        //Check whether is the juro of the dispute
        uint juror_sn = 0;
        
        
        for(uint kk=0;kk<dispute.jurorSNs.length;kk++){
            if(dispute.jurorSNs[kk]==voter_sn){
                juror_sn = kk+1;
                break;
            }
        }

        require( juror_sn>0 , "Only the juror of this dispute can execute rule function.");
        
        uint old_choice = dispute.jurorChoices[ juror_sn-1 ];
        if( old_choice>0 ){
            //Existed choice
            dispute.choiceVoteCounters[ old_choice ] --;
        }

        dispute.jurorChoices[ juror_sn-1 ] = _ruling;
        dispute.choiceVoteCounters[ _ruling ] ++;
        
        if(dispute.choiceVoteCounters[ _ruling ]> dispute.jurorSNs.length/2){
            dispute.ruling = _ruling;
            dispute.status = DisputeStatus.Solved;
    
            //投票正确的陪审员分享50%的仲裁费用
            uint correct_juror_num = dispute.choiceVoteCounters[ _ruling ];
            uint256 correct_vote_bonus = (dispute.arbitrationFee / 2)/correct_juror_num;
            
            for(uint jj=0;jj<dispute.jurorNum ;jj++){
                if(dispute.jurorChoices[jj]==_ruling){
                    uint tmp_pson = dispute.jurorSNs[jj]-VOTER_SN_START;
                    VoterInfo memory  voterInfo = registeredVoterList[tmp_pson];

                    voterInfo.voterBonusWei += correct_vote_bonus;
                    registeredVoterList[tmp_pson] = voterInfo;
                }
            }
            
            //剩余50%的仲裁费用将累积用于按持有DAOToken数量比例进行分红
            daoSharedBonusWei += dispute.arbitrationFee - correct_vote_bonus * correct_juror_num;

            dispute.arbitrated.rule(_disputeID, _ruling);
        }
    }


    function appeal(uint256 _disputeID, bytes memory _extraData) public override payable {
        require(msg.value >= appealCost(_disputeID, _extraData), "Not enough ETH to cover arbitration costs.");
    }

    function appealPeriod(uint256 _disputeID) public override pure returns (uint256 start, uint256 end) {
        return (0, 0);
    }
    
    /*
    function bytesToUint(bytes memory b) public view returns (uint256){
        
        uint256 number;
        for(uint i= 0; i<b.length; i++){
            number = number + uint8(b[i])*(2**(8*(b.length-(i+1))));
        }
        return  number;
    }
    
    function uintToBytes(uint256 x) returns (bytes b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }
    */
}

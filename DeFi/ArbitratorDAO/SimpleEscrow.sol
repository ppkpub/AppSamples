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

import "../IArbitrable.sol";
import "../IArbitrator.sol";

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

contract SimpleEscrow is IArbitrable {
    //address payable public payer = msg.sender;
    //address payable public payee;
    //uint256 public value;
    //IArbitrator public arbitrator;
    //string public agreement;
    //uint256 public createdAt; 
    uint256 public constant reclamationPeriod = 30 minutes;
    uint256 public constant arbitrationFeeDepositPeriod = 30 minutes;

    enum Status {Initial, Reclaimed, Disputed, Resolved}
    //Status public status;

   // uint256 public reclaimedAt;

    enum RulingOptions {RefusedToArbitrate, PayerWins, PayeeWins}
    uint256 constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate.
    
    struct Fund {
        IArbitrator arbitrator;
        address payable payer;
        address payable payee;
        uint256 value;
        bytes agreement;
        Status status;
        uint256 reclaimedAt;
    } 
    
    mapping( uint256 => Fund ) public    mapDisputeFunds;

    constructor( )  {

    }
    
    function createFund(IArbitrator _arbitrator , address payable _payee,bytes memory _agreement) public payable returns (uint256 disputeID){
        require( !Address.isContract(msg.sender) , 
                 "Only normal address could create fund.");    
                 
        require( !Address.isContract( _payee ) , 
                 "Only normal address could be payee.");    
    
        uint256 arbitration_cost = _arbitrator.arbitrationCost(_agreement);
        require(
            msg.value > arbitration_cost,
            "Can't reclaim funds without depositing arbitration fee."
        );
        
        uint escrow_value =  msg.value - arbitration_cost;
        
        (disputeID)=_arbitrator.createDispute{value: arbitration_cost}(numberOfRulingOptions, _agreement);
        /*
        require(
            mapDisputeFunds[disputeID].value==0,
            "Existed disputeID"
        );
        */
        mapDisputeFunds[disputeID] = Fund({
                arbitrator: _arbitrator,
                payer: msg.sender,
                payee: _payee,
                value: escrow_value,
                agreement: _agreement,
                status: Status.Disputed,
                reclaimedAt:block.timestamp
            });
            
       
    }
    
    function getDisputeFundInfo( uint dispute_id ) public view
            returns ( Fund memory fund_record)
    {
        fund_record = mapDisputeFunds[dispute_id];
    }
    
    function rule(uint256 _disputeID, uint256 _ruling) public override {
        Fund memory fund =  mapDisputeFunds[_disputeID];
        require(
            fund.value>0,
            "Not existed disputeID"
        );
    
        require( address(fund.arbitrator) == msg.sender  , "Only the fund arbitrator can execute this.");
        require( fund.status == Status.Disputed, "There should be dispute to execute a ruling.");
        require(_ruling <= numberOfRulingOptions, "Ruling out of bounds!");

        fund.status = Status.Resolved;
        if (_ruling == uint256(RulingOptions.PayerWins)) fund.payer.transfer(fund.value);
        else if (_ruling == uint256(RulingOptions.PayeeWins)) fund.payee.transfer(fund.value);
        emit Ruling(fund.arbitrator, _disputeID, _ruling);
        
        mapDisputeFunds[_disputeID] = fund;
    }

    /*
    function releaseFunds() public {
        require(status == Status.Initial, "Transaction is not in Initial state.");

        if (msg.sender != payer)
            require(block.timestamp - createdAt > reclamationPeriod, "Payer still has time to reclaim.");

        status = Status.Resolved;
        payee.send(value);
    }

    function reclaimFunds() public payable {
        require(
            status == Status.Initial || status == Status.Reclaimed,
            "Transaction is not in Initial or Reclaimed state."
        );
        require(msg.sender == payer, "Only the payer can reclaim the funds.");

        if (status == Status.Reclaimed) {
            require(
                block.timestamp - reclaimedAt > arbitrationFeeDepositPeriod,
                "Payee still has time to deposit arbitration fee."
            );
            payer.send(address(this).balance);
            status = Status.Resolved;
        } else {
            require(block.timestamp - createdAt <= reclamationPeriod, "Reclamation period ended.");
            require(
                msg.value == arbitrator.arbitrationCost("1"),
                "Can't reclaim funds without depositing arbitration fee."
            );
            reclaimedAt = block.timestamp;
            status = Status.Reclaimed;
        }
    }

    function depositArbitrationFeeForPayee() public payable {
        require(status == Status.Reclaimed, "Transaction is not in Reclaimed state.");
        arbitrator.createDispute{value: msg.value}(numberOfRulingOptions, "");
        status = Status.Disputed;
    }
    */

    

    /*
    function remainingTimeToReclaim() public view returns (uint256) {
        if (status != Status.Initial) revert("Transaction is not in Initial state.");
        return
            (createdAt + reclamationPeriod - block.timestamp) > reclamationPeriod
                ? 0
                : (createdAt + reclamationPeriod - block.timestamp);
    }

    function remainingTimeToDepositArbitrationFee() public view returns (uint256) {
        if (status != Status.Reclaimed) revert("Transaction is not in Reclaimed state.");
        return
            (reclaimedAt + arbitrationFeeDepositPeriod - block.timestamp) > arbitrationFeeDepositPeriod
                ? 0
                : (reclaimedAt + arbitrationFeeDepositPeriod - block.timestamp);
    
    */
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.8.0 < 0.9.0;
pragma experimental ABIEncoderV2;

import './interfaces/ICERC20.sol';
import './interfaces/IERC20.sol';
import './interfaces/ICETH.sol';
import './interfaces/IComptroller.sol';

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    ContextDefinitions,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

///@author StreamRoll team:)
///@title StreamRollV1
///@notice it accepts eth as collateral and exchanges it for
///cEth.. Everything happens inside the contract, behaving like a pool.
/// It then streams chunks to the desired accounts.
contract StreamRollV1 is KeeperCompatibleInterface {
    
    ICETH cEth;
    ICERC20 cDai;
    IComptroller comptroller;

    uint public immutable interval;
    uint public lastTimeStamp;
    uint public number;

    event Log(string, address, uint);

    ///@dev To keep track of balances and authorize
    ///transactions. balances = wei. wei = 1 eth * 10 ^18
    ///checkout = wei. This is the redeemed amount ready to checkout
    ///borrowedBalances = amount borrowed in the underlying asset 
    mapping(address => uint) public balances;
    mapping(address => uint) public checkout;
    mapping(address => uint) public borrowedBalances;

    ///@dev cEth --> the contract's address for cEther on rinkeby
    ///cDai--> the contract's address for cDai on rinkeby
    constructor() {
        ///@dev Kovan addresses
        cEth = ICETH(0x41B5844f4680a8C38fBb695b7F9CFd1F64474a72); 
        cDai = ICERC20(0xF0d0EB522cfa50B716B3b1604C4F0fA6f04376AD);
        comptroller = IComptroller(0x5eAe89DC1C671724A672ff0630122ee834098657);

        ///@param interval is the time interval in seconds
        ///@param lastTimeStamp is the time of contract deployment
        interval = 180;
        lastTimeStamp = block.timestamp;
    }

    receive() external payable {}

    ///@dev supplyEthToCompund --> accepts ether and mints cEth.
    ///Everything stays inside our contract, behaving like a pool.
    function supplyEthToCompound() external payable returns (bool) {
        cEth.mint{value: msg.value}();
        balances[msg.sender] += msg.value;
        emit Log("New balance", msg.sender, msg.value);
        return true;
    }

    ///@dev Converts cEth to Eth. The _amount is in wei
    ///Eth goes back to this contract.
    function getEtherBack(uint _amount) external returns (bool) {
        require(balances[msg.sender] > 0);
        require(balances[msg.sender] >= _amount, "Not enough funds");
        require(cEth.redeemUnderlying(_amount) == 0, "ERROR");
        balances[msg.sender] -= _amount;
        checkout[msg.sender] += _amount;
        emit Log("New CHECKOUT REQUESTED", msg.sender, _amount);
        return true;
    }

    ///The amount in cEth wei of the corresponding account.
    /// balance = eth * exchangeRate * 10^18
    function getBalance(address _requested) external view returns (uint) {
        return balances[_requested];
    }

    ///The amount ready to re-send to the msg.sender.
    ///Amount in wei
    function getCheckout(address _requested) external view returns (uint) {
        return checkout[_requested];
    }

    ///@dev transfers the converted amount back to the sender. 
    ///this transfer is in wei.
    ///_amount = wei
    function transferBack(uint _amount, address payable _to) external returns (bool) {
        require(checkout[msg.sender] > 0, "zero balance not supported");
        require(checkout[msg.sender] >= _amount, "Not enough funds");
        require(msg.sender == _to, "INCORRECT ADDRESS");
        (bool sent, bytes memory data) = _to.call{value:_amount}("");
        require(sent, "Transaction Failed");
        checkout[msg.sender] -= _amount;
        emit Log("Transfer succesfull", msg.sender, _amount);
        return true;
    } 

    ///@dev borrowFromCompund transfers the collateral asset to the protocol 
    ///and creates a borrow balance that begins accumulating interests based
    ///on the borrow rate. The amount borrowed must be less than the 
    ///user's collateral balance multiplied by the collateral factor * exchange rate
    function borrowFromCompound(uint _amount) public payable returns (bool) {
        address[] memory cTokens = new address[](2);
        // kovan cETH address
        cTokens[0] = 0x41B5844f4680a8C38fBb695b7F9CFd1F64474a72;
        // kovan cDAI address
        cTokens[1] = 0xF0d0EB522cfa50B716B3b1604C4F0fA6f04376AD;
        uint[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
           revert("Comptroller.enterMarkets failed");
       }
       require(cDai.borrow(_amount) == 0, "Not Working");
       borrowedBalances[msg.sender] += _amount;
       return true;
    }

    ///@dev returns the total borrowed amount for the EOA accounts.
    function returnBorrowedBalances() external view returns (uint) {
        return borrowedBalances[msg.sender];
    }

    ///@dev returns the total borrowed amount of this smart contract
    function streamRollTotalBorrowed() external returns (uint) {
        return cDai.borrowBalanceCurrent(address(this));
    }

    ///@dev repays the borrowed amount in dai
    ///@param _repayAmount = dai * 10 ^18
    function repayDebt(uint _repayAmount) external returns (bool) {
        // kovan DAI address
        IERC20 underlying = IERC20(0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa);
        // kovan cDAI address
        underlying.approve(0xF0d0EB522cfa50B716B3b1604C4F0fA6f04376AD, _repayAmount);
        require(cDai.repayBorrow(_repayAmount) == 0, "Error in repayBorrow()");
        borrowedBalances[msg.sender] -= _repayAmount;
        return true;
    }
    
    ///////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////  KEEPER INTERFACE  ///////////////////////////
    ///////////////////////////////////////////////////////////////////////////////

    ///@dev This function is to test if the Keepers are working
    function math() public returns (uint) {
        number = number + 2;
    } 

    function checkUpkeep(bytes calldata checkData) 
        external override view returns (bool upkeepNeeded, bytes memory performData) {
            upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;

            performData = checkData;
    }
    ///@notice borrowFromCompound needs to be commented out for math() to be called.
    ///TODO: Get the keeper to call borrowFromCompound() correctly. 
    function performUpkeep(bytes calldata performData) external override {
        lastTimeStamp = block.timestamp;
        math();
        borrowFromCompound(.01 * 10 ** 18);

        performData;
    }
}

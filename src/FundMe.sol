//purpose:
//Get funds from users
//Withdraw funds
//Set a minimum funding value in USD

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract FundMe{
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 5e18;

    address[] private s_funders;
    mapping(address funder => uint256 amountFunded) private s_addressToAmount;

    address private immutable i_owner;

    error FundMe__NotOwner();
    AggregatorV3Interface private s_priceFeed;

    constructor(address priceFeed){
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable {
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "didn't send enough value");
        //revert:if the requirement above is not satified, the transaction will be revert and it undo the previous actions
        //but U'll still spend gas
        s_funders.push(msg.sender);
        s_addressToAmount[msg.sender] += msg.value;
    }

    function getVersion() public view returns(uint256){
        return s_priceFeed.version();
    }

    function cheaperWithdraw() public onlyOwner{
        uint256 fundersLength = s_funders.length;
        for(uint256 funderIndex = 0; funderIndex < fundersLength; funderIndex++){
            address funder = s_funders[funderIndex];
            s_addressToAmount[funder]=0;
        }
        s_funders = new address[](0); 
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    function withdraw() public onlyOwner{
        for(uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++){
            address funder = s_funders[funderIndex];
            s_addressToAmount[funder]=0;
        }
        //reset the array
        s_funders = new address[](0); //funders被设置为长度为0的数组

        //发送ETH有三种方法，transfer(),send(),call()

        //transfer:如果转账失败，return error
            //payable(msg.sender).transfer(address(this).balance);
        //msg.sender是address类型，但不一定是payable address，只有payable address可以被transfer

        //send:如果转账失败，返回bool
            //bool sendSeccess = payable(msg.sender).send(address(this).balance);
            //require(sendSeccess, "Send failed");

        //call:best prictice
       (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
       require(callSuccess, "Call failed");
    }

    modifier onlyOwner(){
        //require(msg.sender == i_owner, "Must be owner");
        if(msg.sender != i_owner){
            revert FundMe__NotOwner();
        }
        _;//先检查require再继续运行程序
    }

    receive() external payable { 
        fund();
    }
    fallback() external payable {
        fund();
     }

    /**getters
     * View/pure functions do not cost gas
     */

    function getAddressToAmount(address fundingAddress) external view returns(uint256){
        return s_addressToAmount[fundingAddress];
    }

    function getFunders(uint256 index) external view returns(address){
        return s_funders[index];
    }

    function getOwner() external view returns(address){
        return i_owner;
    }
}
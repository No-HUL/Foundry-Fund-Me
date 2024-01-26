// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {Test,console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol"; 

contract FundMeTest is Test{
    FundMe fundMe;

    address USER = makeAddr("user"); //makeaddr创建了一个虚拟地址，该函数在forge-std/Script.sol中
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external{
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();// 在测试中部署合约
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public{
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }
    function testOwnerIsMsgSender() public{
        console.log("msg.sender is", msg.sender);
        console.log("i_owner is", fundMe.getOwner());
        //assertEq(fundMe.i_owner(), msg.sender); 
        //failed,因为msg.sender是调用者，在这里调用者是测试合约（FundMeTest），而不是部署合约的DeployFundMe
        //所以测试合约的msg.sender和部署合约的msg.sender不一样，要assert的是这个测试合约的地址是不是i_owner
        //assertEq(fundMe.i_owner(), address(this));
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public{
        assertEq(fundMe.getVersion(), 4);
    }

    function testFundFailsWithoutEnoughMoney() public {
        vm.expectRevert();
        fundMe.fund{value: 4}();
    }

    function testFundUpdatesFunderBalance() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        uint256 amountFunded = fundMe.getAddressToAmount(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddFundersToArray() public funded{
        address funder = fundMe.getFunders(0);
        assertEq(funder, USER);
    }
    
    modifier funded(){
        vm.prank(USER);// 这个函数假设了下一个tx被USER发送
        //在setup中，我们给USER发送了10 ether，所以这里USER有钱
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded{
        vm.expectRevert();
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded{
        //1. Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeContractBalance = address(fundMe).balance;
        //2. Act
        //uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        //uint256 gasEnd = gasleft();
        //uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        //console.log("gasUsed is", gasUsed);
        //3. Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeContractBalance = address(fundMe).balance;
        assertEq(endingFundMeContractBalance,0);
        assertEq(endingOwnerBalance,startingOwnerBalance + startingFundMeContractBalance);
    }

    function testWithdrawWithMultipleFunders() public funded{
        //1. Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for(uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            hoax(address(i), SEND_VALUE); // hoax=prank+deal
            fundMe.fund{value: SEND_VALUE}();
        }
        //2. Act
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeContractBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();
        //3. Assert
        assertEq(address(fundMe).balance, 0);
        assertEq(fundMe.getOwner().balance, startingOwnerBalance + startingFundMeContractBalance);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployFundMe} from "../../script/Deployfundme.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    HelperConfig public helperConfig;

    address USER = makeAddr("User");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function setUp() external {
        DeployFundMe deployer = new DeployFundMe();
        (fundMe, helperConfig) = deployer.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMessageSender() public view {
        console.log(fundMe.getOwner());
        console.log(msg.sender);
        assertEq(fundMe.getOwner(), address(msg.sender));
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.startPrank(USER);
        fundMe.fund{value: SEND_VALUE}();
        vm.stopPrank();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithdrawFromASingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log(gasUsed);

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        console.log("SOB:", startingOwnerBalance);
        console.log("SFB:", startingFundMeBalance);
        console.log("EOB:", endingOwnerBalance);
        console.log("EFB:", endingFundMeBalance);

        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
        assertEq(endingFundMeBalance, 0);
    }

    // gas: 538260
    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            fundMe.getOwner().balance
        );
        assertEq(
            (1 + numberOfFunders) * SEND_VALUE,
            fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    // gas: 537439
    function testWithdrawFromMultipleFundersWithCheaper() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdrawMoreCheap();
        vm.stopPrank();

        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            fundMe.getOwner().balance
        );
        assertEq(
            (1 + numberOfFunders) * SEND_VALUE,
            fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    // 535364
    function testWithdrawFromMultipleFundersWithMemoryArray() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdrawMemory();
        vm.stopPrank();

        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            fundMe.getOwner().balance
        );
        assertEq(
            (1 + numberOfFunders) * SEND_VALUE,
            fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    // expensiver than testWithdrawFromMultipleFundersWithMemoryArray
    function testWithdrawFromMultipleFundersWithMemoryArrayCheaper()
        public
        funded
    {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), STARTING_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdrawMemoryCheaper();
        vm.stopPrank();

        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            fundMe.getOwner().balance
        );
        assertEq(
            (1 + numberOfFunders) * SEND_VALUE,
            fundMe.getOwner().balance - startingOwnerBalance
        );
    }
}

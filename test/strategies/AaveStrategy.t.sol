// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AaveStrategy} from "src/strategies/AaveStrategy.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

contract MockAavePool is IPool {
    address public lastCaller;
    bytes public lastCallData;

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        lastCaller = msg.sender;
        lastCallData = abi.encode(asset, amount, onBehalfOf, referralCode);
    }
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        lastCaller = msg.sender;
        lastCallData = abi.encode(asset, amount, to);
        return amount;
    }
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external {}
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256) { return amount; }
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory) { return DataTypes.ReserveData(DataTypes.ReserveConfigurationMap(0),0,0,0,0,0,0,0,address(0),address(0),address(0),address(0),0,0,0); }
    function getUserAccountData(address user) external view returns (uint256, uint256, uint256, uint256, uint256, uint256) { return (0,0,0,0,0,0); }
    function getConfiguration(address asset) external view returns (DataTypes.ReserveConfigurationMap memory) { return DataTypes.ReserveConfigurationMap(0); }
    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider) { return IPoolAddressesProvider(address(0)); } // Mock return
    function BRIDGE_PROTOCOL_FEE() external view returns (uint256) { return 0; }
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128) { return 0; }
    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint128) { return 0; }
    function MAX_NUMBER_RESERVES() external view returns (uint16) { return 0; }
    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external view returns (uint256) { return 0; }
    function backUnbacked(address asset, uint256 amount, uint256 fee) external returns (uint256) { return 0; }
    function configureEModeCategory(uint8 id, DataTypes.EModeCategory memory config) external {}
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {}
    function dropReserve(address asset) external {}
    function finalizeTransfer(address asset, address from, address to, uint256 amount, uint256 balanceFromAfter, uint256 balanceToBefore) external {}
    function flashLoanSimple(address receiverAddress, address asset, uint256 amount, bytes calldata params, uint16 referralCode) external {}
    function getEModeCategoryData(uint8 id) external view returns (DataTypes.EModeCategory memory) { DataTypes.EModeCategory memory config; return config; }
    function getReserveAddressById(uint16 id) external view returns (address) { return address(0); }
    function getUserConfiguration(address user) external view returns (DataTypes.UserConfigurationMap memory) { return DataTypes.UserConfigurationMap(0); }
    function getUserEMode(address user) external view returns (uint256) { return 0; }
    function initReserve(address asset, address aTokenAddress, address stableDebtAddress, address variableDebtAddress, address interestRateStrategyAddress) external {}
    function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode) external returns (uint256) { return 0; }
    function repayWithPermit(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external returns (uint256) { return 0; }
    function resetIsolationModeTotalDebt(address asset) external {}
    function setConfiguration(address asset, DataTypes.ReserveConfigurationMap calldata configuration) external {}
    function setUserEMode(uint8 categoryId) external {}
    function supplyWithPermit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {}
    function updateBridgeProtocolFee(uint256 bridgeProtocolFee) external {}
    function updateFlashloanPremiums(uint128 flashLoanPremiumTotal, uint128 flashLoanPremiumToProtocol) external {}

    // --- Unused Mock Functions ---
    function setUserUseReserveAsCollateral(address, bool) external {}
    function liquidationCall(address, address, address, uint256, bool) external {}
    function swapBorrowRateMode(address, uint256) external {}
    function rebalanceStableBorrowRate(address, address) external {}
    function getReserveNormalizedIncome(address) external view returns (uint256) {}
    function getReserveNormalizedVariableDebt(address) external view returns (uint256) {}
    function flashLoan(address, address[] calldata, uint256[] calldata, uint256[] calldata, address, bytes calldata, uint16) external {}
    function mintToTreasury(address[] calldata) external {}
    function borrow(address, uint256, uint256, uint16, address, bytes calldata) external {}
    function repay(address, uint256, uint256, address, bytes calldata) external returns (uint256) {}
    function repayWithATokens(address, uint256, uint256, address) external returns (uint256) {}
    function repayWithPermit(address, uint256, uint256, address, uint256, bytes calldata) external returns (uint256) {}
    function supplyWithPermit(address, uint256, address, uint16, uint256, bytes calldata) external {}
    function setReserveInterestRateStrategyAddress(address, address) external {}
    function mintUnbacked(address, uint256, address, uint16) external {}
    function rescueTokens(address, address, uint256) external {}
    function getReservesList() external view returns (address[] memory) {}
    function POOL_REVISION() external view returns (uint256) {}
}

contract AaveStrategyTest is Test {
    AaveStrategy public strategy;
    ERC20Mock public asset;
    ERC20Mock public aToken;
    MockAavePool public pool;

    uint256 internal constant DEPOSIT_AMOUNT = 100e18;

    function setUp() public {
        asset = new ERC20Mock("Asset", "ASSET", 18);
        aToken = new ERC20Mock("aAsset", "aASSET", 18);
        pool = new MockAavePool();
        strategy = new AaveStrategy(address(pool), address(asset), address(aToken));

        asset.mint(address(strategy), DEPOSIT_AMOUNT);
    }

    function test_deposit() public {
        strategy.deposit(DEPOSIT_AMOUNT);

        // Check that pool was called correctly
        assertEq(pool.lastCaller(), address(strategy), "Caller should be strategy");
        (address receivedAsset, uint256 receivedAmount, ,) = abi.decode(pool.lastCallData(), (address, uint256, address, uint16));
        assertEq(receivedAsset, address(asset), "Asset address in pool call");
        assertEq(receivedAmount, DEPOSIT_AMOUNT, "Amount in pool call");
    }

    function test_withdraw() public {
        strategy.withdraw(DEPOSIT_AMOUNT);

        assertEq(pool.lastCaller(), address(strategy), "Caller should be strategy");
        (address receivedAsset, uint256 receivedAmount, ) = abi.decode(pool.lastCallData(), (address, uint256, address));
        assertEq(receivedAsset, address(asset), "Asset address in pool call");
        assertEq(receivedAmount, DEPOSIT_AMOUNT, "Amount in pool call");
    }

    function test_totalAssets() public {
        uint256 expectedBalance = 500e18;
        aToken.mint(address(strategy), expectedBalance);

        assertEq(strategy.totalAssets(), expectedBalance, "totalAssets should be balance of aToken");
    }
}

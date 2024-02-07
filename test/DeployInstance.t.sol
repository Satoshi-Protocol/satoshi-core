// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../src/interfaces/dependencies/AggregatorV3Interface.sol";
import {IPriceFeed} from "../src/interfaces/dependencies/IPriceFeed.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {OracleMock} from "../src/mocks/OracleMock.sol";
import {PriceFeedChainlink} from "../src/dependencies/priceFeed/PriceFeedChainlink.sol";
import {DeploymentParams} from "../src/core/Factory.sol";
import {DeployBase} from "./utils/DeployBase.t.sol";
import {
    DEPLOYER,
    OWNER,
    COLLATERAL_ADDRESS,
    MINUTE_DECAY_FACTOR,
    REDEMPTION_FEE_FLOOR,
    MAX_REDEMPTION_FEE,
    BORROWING_FEE_FLOOR,
    MAX_BORROWING_FEE,
    INTEREST_RATE_IN_BPS,
    MAX_DEBT,
    MCR
} from "./TestConfig.sol";

contract DeployInstanceTest is Test, DeployBase {
    uint8 internal constant ORACLE_MOCK_DECIMALS = 8;
    uint256 internal constant ORACLE_MOCK_VERSION = 1;
    IERC20 internal constant COLLATERAL = IERC20(COLLATERAL_ADDRESS);

    RoundData internal ROUND_DATA =
        RoundData({answer: 4000000000000, startedAt: 1630000000, updatedAt: 1630000000, answeredInRound: 1});

    DeploymentParams internal deploymentParams = DeploymentParams({
        minuteDecayFactor: MINUTE_DECAY_FACTOR,
        redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
        maxRedemptionFee: MAX_REDEMPTION_FEE,
        borrowingFeeFloor: BORROWING_FEE_FLOOR,
        maxBorrowingFee: MAX_BORROWING_FEE,
        interestRateInBps: INTEREST_RATE_IN_BPS,
        maxDebt: MAX_DEBT,
        MCR: MCR
    });

    function setUp() public override {
        super.setUp();

        // compute all contracts address
        _computeContractsAddress(DEPLOYER);

        // deploy all implementation contracts
        _deployImplementationContracts(DEPLOYER);

        // deploy all non-upgradeable contracts
        _deployNonUpgradeableContracts(DEPLOYER);

        // deploy all UUPS upgradeable contracts
        _deployUUPSUpgradeableContracts(DEPLOYER);

        // deploy all beacon contracts
        _deployBeaconContracts(DEPLOYER);
    }

    function testDeployInstance() public {
        // deploy oracle mock contract to simulate price feed source
        address oracleAddr = _deployOracleMock(DEPLOYER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION);
        // update data to the oracle mock
        _updateRoundData(DEPLOYER, oracleAddr, ROUND_DATA);

        // deploy price feed chainlink contract
        address priceFeedChainlinkAddr = _deployPriceFeedChainlink(DEPLOYER, AggregatorV3Interface(oracleAddr));

        vm.startPrank(OWNER);

        uint256 troveManagerCountBefore = factory.troveManagerCount();

        priceFeedAggregatorProxy.setPriceFeed(COLLATERAL, IPriceFeed(priceFeedChainlinkAddr));
        factory.deployNewInstance(COLLATERAL, IPriceFeed(priceFeedChainlinkAddr), deploymentParams);

        uint256 troveManagerCountAfter = factory.troveManagerCount();
        
        assert(troveManagerCountAfter == troveManagerCountBefore + 1);

        uint256 stabilityPoolIndexByCollateral = stabilityPoolProxy.indexByCollateral(COLLATERAL);
        assert(stabilityPoolProxy.collateralTokens(stabilityPoolIndexByCollateral - 1) == COLLATERAL); // index - 1 
        
        ITroveManager troveManagerBeaconProxy = factory.troveManagers(troveManagerCountAfter - 1);
        ISortedTroves sortedTrovesBeaconProxy = troveManagerBeaconProxy.sortedTroves();
        assert(sortedTrovesBeaconProxy.troveManager() == troveManagerBeaconProxy);
        
        assert(troveManagerBeaconProxy.collateralToken() == COLLATERAL);
        assert(troveManagerBeaconProxy.systemDeploymentTime() != 0);
        assert(troveManagerBeaconProxy.sunsetting() == false);
        assert(troveManagerBeaconProxy.lastActiveIndexUpdate() != 0);

        assert(debtToken.troveManager(troveManagerBeaconProxy) == true);

        (IERC20 collateralToken, ) = borrowerOperationsProxy.troveManagersData(troveManagerBeaconProxy);
        assert(collateralToken == COLLATERAL);

        vm.stopPrank();
    }

    function _deployOracleMock(address deployer, uint8 decimals, uint256 version) internal returns (address) {
        vm.startPrank(deployer);
        address oracleAddr = address(new OracleMock(decimals, version));
        vm.stopPrank();
        return oracleAddr;
    }

    function _updateRoundData(address caller, address oracleAddr, RoundData memory roundData) internal {
        vm.startPrank(caller);
        assert(oracleAddr != address(0)); // check if oracle contract is deployed
        OracleMock(oracleAddr).updateRoundData(roundData);
        vm.stopPrank();
    }

    function _deployPriceFeedChainlink(address deployer, AggregatorV3Interface oracle) internal returns (address) {
        vm.startPrank(deployer);
        assert(oracle != AggregatorV3Interface(address(0))); // check if oracle contract is deployed
        address priceFeedChainlinkAddr = address(new PriceFeedChainlink(oracle));
        vm.stopPrank();
        return priceFeedChainlinkAddr;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {
    DEPLOYER,
    OWNER,
    GUARDIAN,
    GAS_COMPENSATION,
    TestConfig,
    REWARD_MANAGER,
    FEE_RECEIVER,
    _1_MILLION
} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {INTEREST_RATE_IN_BPS, REWARD_MANAGER_GAIN, REWARD_MANAGER_PRECISION} from "./TestConfig.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {IPriceFeed, SourceConfig} from "../src/interfaces/dependencies/IPriceFeed.sol";
import {IDIAOracleV2} from "../src/interfaces/dependencies/priceFeed/IDIAOracleV2.sol";
import {IProxy} from "@api3/contracts/api3-server-v1/proxies/interfaces/IProxy.sol";
import {PriceFeedAPI3Oracle} from "../src/dependencies/priceFeed/PriceFeedAPI3Oracle.sol";
import {PriceFeedChainlink} from "../src/dependencies/priceFeed/PriceFeedChainlink.sol";
import {PriceFeedChainlinkAggregator} from "../src/dependencies/priceFeed/PriceFeedChainlinkAggregator.sol";
import {PriceFeedChainlinkExchangeRate} from "../src/dependencies/priceFeed/PriceFeedChainlinkExchangeRate.sol";
import {PriceFeedDIAOracle} from "../src/dependencies/priceFeed/PriceFeedDIAOracle.sol";
import {PriceFeedPythOracle} from "../src/dependencies/priceFeed/PriceFeedPythOracle.sol";
import {RoundData, OracleMock} from "../src/mocks/OracleMock.sol";
import {DIAOracleV2} from "../src/mocks/DIAOracleV2.sol";
import {DataFeedProxy} from "../src/mocks/API3Mock.sol";
import {AggregatorV3Interface} from "../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";

contract PriceFeedAggregatorTest is Test, DeployBase, TroveBase, TestConfig, Events {
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    IPriceFeed chainlink;
    IPriceFeed pythOracle;
    IPriceFeed api3;
    IPriceFeed dia;

    RoundData internal roundData;

    function setUp() public override {
        super.setUp();

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));

        roundData = RoundData({
            answer: 4000000000000,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
    }

    function testFetchPrice() public {
        assertEq(priceFeedAggregatorProxy.fetchPrice(collateralMock), 40000e18);

        vm.warp(block.timestamp + 2 days);
        vm.expectRevert(IPriceFeed.PriceTooOld.selector);
        priceFeedAggregatorProxy.fetchPrice(collateralMock);
    }

    function testFetchPriceUnsafe() public {
        (uint256 price, uint256 lastUpdated) = priceFeedAggregatorProxy.fetchPriceUnsafe(collateralMock);
        assertEq(price, 40000e18);
        assertEq(lastUpdated, block.timestamp);
    }

    function testChainlinkOracle() public {
        uint256 answer = 50000e18;
        uint8 decimals = 18;
        roundData = RoundData({
            answer: int256(answer),
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
        address priceFeed = _deployPriceFeed(DEPLOYER, decimals, ORACLE_MOCK_VERSION, roundData);
        assertEq(IPriceFeed(priceFeed).fetchPrice(), answer);
        (uint256 price, uint256 time) = IPriceFeed(priceFeed).fetchPriceUnsafe();
        assertEq(price, answer);
        assertEq(time, block.timestamp);
        assertEq(IPriceFeed(priceFeed).decimals(), decimals);
        assertEq(IPriceFeed(priceFeed).source(), oracleMockAddr);

        vm.startPrank(OWNER);
        IPriceFeed(priceFeed).updateMaxTimeThreshold(150);
        assertEq(IPriceFeed(priceFeed).maxTimeThreshold(), 150);
        vm.expectRevert(IPriceFeed.InvalidMaxTimeThreshold.selector);
        IPriceFeed(priceFeed).updateMaxTimeThreshold(100);
        vm.stopPrank();
    }

    function testChainlinkAggregatorOracle() public {
        uint256 answer0 = 50000e18;
        uint8 decimals = 18;
        roundData = RoundData({
            answer: int256(answer0),
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });

        oracleMockAddr = _deployOracleMock(DEPLOYER, decimals, ORACLE_MOCK_VERSION);
        _updateRoundData(DEPLOYER, oracleMockAddr, roundData);

        uint256 answer1 = 100000e18;
        roundData = RoundData({
            answer: int256(answer1),
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
        address oracleMockAddr1 = _deployOracleMock(DEPLOYER, decimals, ORACLE_MOCK_VERSION);
        _updateRoundData(DEPLOYER, oracleMockAddr1, roundData);

        SourceConfig[] memory sources = new SourceConfig[](2);
        sources[0] = SourceConfig({source: AggregatorV3Interface(oracleMockAddr), maxTimeThreshold: 3600, weight: 1});
        sources[1] = SourceConfig({source: AggregatorV3Interface(oracleMockAddr1), maxTimeThreshold: 3600, weight: 1});

        // deploy chainlink aggregator
        address priceFeed = _deployPriceFeedChainlinkAggregator(DEPLOYER, satoshiCore, sources);

        assertEq(IPriceFeed(priceFeed).fetchPrice(), (answer0 + answer1) / 2);
        (uint256 price, uint256 time) = IPriceFeed(priceFeed).fetchPriceUnsafe();
        assertEq(price, (answer0 + answer1) / 2);
        assertEq(time, block.timestamp);
        assertEq(IPriceFeed(priceFeed).decimals(), 18);

        vm.startPrank(OWNER);
        sources[0] = SourceConfig({source: AggregatorV3Interface(oracleMockAddr), maxTimeThreshold: 7200, weight: 2});
        sources[1] = SourceConfig({source: AggregatorV3Interface(oracleMockAddr1), maxTimeThreshold: 7200, weight: 1});
        PriceFeedChainlinkAggregator(priceFeed).setConfig(sources);
        assertEq(IPriceFeed(priceFeed).fetchPrice(), (answer0 * 2 + answer1) / 3);
        assertEq(PriceFeedChainlinkAggregator(priceFeed).maxTimeThresholds(0), 7200);
        assertEq(PriceFeedChainlinkAggregator(priceFeed).maxTimeThresholds(1), 7200);

        vm.stopPrank();
    }

    function testPriceFeedChainlinkExchangeRate() public {
        uint256 answer0 = 50000e8;
        uint8 decimals = 8;
        roundData = RoundData({
            answer: int256(answer0),
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });

        oracleMockAddr = _deployOracleMock(DEPLOYER, decimals, ORACLE_MOCK_VERSION);
        _updateRoundData(DEPLOYER, oracleMockAddr, roundData);

        uint256 answer1 = 1e8;
        roundData = RoundData({
            answer: int256(answer1),
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
        address oracleMockAddr1 = _deployOracleMock(DEPLOYER, decimals, ORACLE_MOCK_VERSION);
        _updateRoundData(DEPLOYER, oracleMockAddr1, roundData);

        SourceConfig[] memory sources = new SourceConfig[](2);
        sources[0] = SourceConfig({source: AggregatorV3Interface(oracleMockAddr), maxTimeThreshold: 3600, weight: 1});
        sources[1] = SourceConfig({source: AggregatorV3Interface(oracleMockAddr1), maxTimeThreshold: 3600, weight: 1});

        // deploy chainlink aggregator
        address priceFeed = _deployPriceFeedChainlinkExchangeRate(DEPLOYER, satoshiCore, sources);

        (, int256 price,, uint256 time,) = PriceFeedChainlinkExchangeRate(priceFeed).latestRoundData();
        assertEq(uint256(price), answer0 * 10 ** (18 - decimals));
        assertEq(time, block.timestamp);
        assertEq(PriceFeedChainlinkExchangeRate(priceFeed).decimals(), 18);

        vm.startPrank(OWNER);
        sources[0] = SourceConfig({source: AggregatorV3Interface(oracleMockAddr), maxTimeThreshold: 7200, weight: 1});
        sources[1] = SourceConfig({source: AggregatorV3Interface(oracleMockAddr1), maxTimeThreshold: 7200, weight: 1});
        PriceFeedChainlinkAggregator(priceFeed).setConfig(sources);
        assertEq(PriceFeedChainlinkAggregator(priceFeed).maxTimeThresholds(0), 7200);
        assertEq(PriceFeedChainlinkAggregator(priceFeed).maxTimeThresholds(1), 7200);

        vm.stopPrank();
    }

    function testDIAOracle() public {
        DIAOracleV2 diaSource = new DIAOracleV2();
        uint128 answer = 50000e8;
        diaSource.setValue("BTC/USD", answer, uint128(block.timestamp));
        address priceFeed = _deployPriceFeedDIA(
            DEPLOYER, IDIAOracleV2(address(diaSource)), satoshiCore, ORACLE_MOCK_DECIMALS, "BTC/USD", 200
        );
        assertEq(IPriceFeed(priceFeed).fetchPrice(), answer);
        (uint256 price, uint256 time) = IPriceFeed(priceFeed).fetchPriceUnsafe();
        assertEq(price, answer);
        assertEq(time, block.timestamp);
        assertEq(IPriceFeed(priceFeed).decimals(), 8);
        assertEq(IPriceFeed(priceFeed).source(), address(diaSource));

        vm.startPrank(OWNER);
        IPriceFeed(priceFeed).updateMaxTimeThreshold(150);
        assertEq(IPriceFeed(priceFeed).maxTimeThreshold(), 150);
        vm.expectRevert(IPriceFeed.InvalidMaxTimeThreshold.selector);
        IPriceFeed(priceFeed).updateMaxTimeThreshold(100);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);
        vm.expectRevert(IPriceFeed.PriceTooOld.selector);
        IPriceFeed(priceFeed).fetchPrice();
    }

    function testAPI3Oracle() public {
        uint128 answer = 50000e8;
        DataFeedProxy api3Source = new DataFeedProxy();
        api3Source.updatePrice(int224(uint224(answer)));
        address priceFeed =
            _deployPriceFeedAPI3(DEPLOYER, IProxy(address(api3Source)), ORACLE_MOCK_DECIMALS, satoshiCore, 200);
        assertEq(IPriceFeed(priceFeed).fetchPrice(), uint256(answer));
        (uint256 price, uint256 time) = IPriceFeed(priceFeed).fetchPriceUnsafe();
        assertEq(price, uint256(answer));
        assertEq(time, block.timestamp);
        assertEq(IPriceFeed(priceFeed).decimals(), 8);
        assertEq(IPriceFeed(priceFeed).source(), address(api3Source));

        vm.startPrank(OWNER);
        IPriceFeed(priceFeed).updateMaxTimeThreshold(150);
        assertEq(IPriceFeed(priceFeed).maxTimeThreshold(), 150);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);
        vm.expectRevert(IPriceFeed.PriceTooOld.selector);
        IPriceFeed(priceFeed).fetchPrice();
    }

    function testSetPriceFeedDecimal18() public {
        uint256 answer = 50000e18;
        uint8 decimals = 18;
        roundData = RoundData({
            answer: int256(answer),
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
        address priceFeed = _deployPriceFeed(DEPLOYER, decimals, ORACLE_MOCK_VERSION, roundData);
        _setPriceFeedToPriceFeedAggregatorProxy(OWNER, collateralMock, IPriceFeed(priceFeed));
        assertEq(priceFeedAggregatorProxy.fetchPrice(collateralMock), answer);
        (uint256 price, uint256 lastUpdated) = priceFeedAggregatorProxy.fetchPriceUnsafe(collateralMock);
        assertEq(price, answer);
        assertEq(lastUpdated, block.timestamp);
    }

    function testSetPriceFeedDecimal27() public {
        uint256 answer = 50000e27;
        uint8 decimals = 27;
        roundData = RoundData({
            answer: int256(answer),
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
        address priceFeed = _deployPriceFeed(DEPLOYER, decimals, ORACLE_MOCK_VERSION, roundData);
        _setPriceFeedToPriceFeedAggregatorProxy(OWNER, collateralMock, IPriceFeed(priceFeed));
        assertEq(priceFeedAggregatorProxy.fetchPrice(collateralMock), 50000e18);
        (uint256 price, uint256 lastUpdated) = priceFeedAggregatorProxy.fetchPriceUnsafe(collateralMock);
        assertEq(price, 50000e18);
        assertEq(lastUpdated, block.timestamp);
    }
}

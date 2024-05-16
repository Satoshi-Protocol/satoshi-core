// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vesting} from "./Vesting.sol";
import {Reserve} from "./Reserve.sol";
import {InvestorVesting} from "./InvestorVesting.sol";
import {IVestingManager, VestingType} from "../interfaces/OSHI/IVestingManager.sol";
import {IReserve} from "../interfaces/OSHI/IReserve.sol";

/**
 * @title Vesting Manager Contract
 *        Deploy the vesting contracts for the team, advisors and investors
 */
contract VestingManager is SatoshiOwnable, IVestingManager, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public token; // OSHI token
    uint256 internal constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore, address _token) external initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        token = IERC20(_token);
    }

    /**
     * @dev Deploy the vesting contract for the team and advisors
     */
    function deployVesting(address _beneficiary, uint256 _amount, uint64 _startTimestamp, VestingType _type)
        external
        onlyOwner
        returns (address)
    {
        require(_beneficiary != address(0), "VestingManager: beneficiary is the zero address");
        require(_amount != 0, "VestingManager: amount is 0");
        require(_type == VestingType.TEAM || _type == VestingType.ADVISOR, "VestingManager: invalid vesting type");

        Vesting vesting = new Vesting(address(token), _amount, _beneficiary, _startTimestamp);
        token.safeTransfer(address(vesting), _amount);
        emit VestingDeployed(address(vesting), _amount, _startTimestamp);

        return address(vesting);
    }

    /**
     * @dev Deploy the vesting contract for the investors
     */
    function deployInvestorVesting(address _beneficiary, uint256 _amount, uint64 _startTimestamp)
        external
        onlyOwner
        returns (address)
    {
        require(_beneficiary != address(0), "VestingManager: beneficiary is the zero address");
        require(_amount != 0, "VestingManager: amount is 0");

        InvestorVesting investorVesting = new InvestorVesting(address(token), _amount, _beneficiary, _startTimestamp);
        token.safeTransfer(address(investorVesting), _amount);
        emit VestingDeployed(address(investorVesting), _amount, _startTimestamp);

        return address(investorVesting);
    }

    /**
     * @dev Deploy the vesting contract for the reserve
     */
    function deployReserveVesting(uint256 _amount, uint64 _startTimestamp) external onlyOwner returns (address) {
        require(_amount != 0, "VestingManager: amount is 0");
        uint64 duration = 6;

        Reserve reserve = new Reserve(SATOSHI_CORE, address(token), _amount, _startTimestamp, duration);
        token.safeTransfer(address(reserve), _amount);
        emit VestingDeployed(address(reserve), _amount, _startTimestamp);

        return address(reserve);
    }
    /**
     * @dev Deploy the vesting contract for the ecosystem
     */

    function deployEcosystemVesting(uint256 _amount, uint64 _startTimestamp) external onlyOwner returns (address) {
        uint64 duration = 3;
        Reserve reserve = new Reserve(SATOSHI_CORE, address(token), _amount, _startTimestamp, duration);
        token.safeTransfer(address(reserve), _amount);
        emit VestingDeployed(address(reserve), _amount, _startTimestamp);

        return address(reserve);
    }
}

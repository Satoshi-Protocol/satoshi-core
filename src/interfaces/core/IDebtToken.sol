// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ITroveManager} from "./ITroveManager.sol";
import {IGasPool} from "./IGasPool.sol";
import {IStabilityPool} from "./IStabilityPool.sol";
import {IBorrowerOperations} from "./IBorrowerOperations.sol";
import {IFactory} from "./IFactory.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";

interface IDebtToken is IERC20Upgradeable {
    function burn(address _account, uint256 _amount) external;

    function burnWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    function enableTroveManager(ITroveManager _troveManager) external;

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool);

    function mint(address _account, uint256 _amount) external;

    function mintWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external;

    function sendToSP(address _sender, uint256 _amount) external;

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function DEBT_GAS_COMPENSATION() external view returns (uint256);

    function FLASH_LOAN_FEE() external view returns (uint256);

    function borrowerOperations() external view returns (IBorrowerOperations);

    function factory() external view returns (IFactory);

    function flashFee(address token, uint256 amount) external view returns (uint256);

    function gasPool() external view returns (IGasPool);

    function maxFlashLoan(address token) external view returns (uint256);

    function stabilityPool() external view returns (IStabilityPool);

    function troveManager(ITroveManager) external view returns (bool);

    function initialize(
        ISatoshiCore _satoshiCore,
        string memory _name,
        string memory _symbol,
        IStabilityPool _stabilityPool,
        IBorrowerOperations _borrowerOperations,
        IFactory _factory,
        IGasPool _gasPool,
        uint256 _gasCompensation
    ) external;

    function wards(address) external view returns (bool);
}

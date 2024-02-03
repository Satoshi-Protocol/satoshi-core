// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC3156FlashBorrowerUpgradeable as IERC3156FlashBorrower} from
    "@openzeppelin/contracts-upgradeable/interfaces/IERC3156FlashBorrowerUpgradeable.sol";
import {IOFT} from "@layerzerolabs/solidity-examples/contracts/token/oft/v1/interfaces/IOFT.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IGasPool} from "../interfaces/IGasPool.sol";
import {IStabilityPool} from "../interfaces/IStabilityPool.sol";
import {IBorrowerOperations} from "../interfaces/IBorrowerOperations.sol";
import {IFactory} from "../interfaces/IFactory.sol";

interface IDebtToken is IOFT {
    function burn(address _account, uint256 _amount) external;

    function burnWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    function enableTroveManager(ITroveManager _troveManager) external;

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool);

    function mint(address _account, uint256 _amount) external;

    function mintWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external;

    function sendToSP(address _sender, uint256 _amount) external;

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function DEBT_GAS_COMPENSATION() external view returns (uint256);

    function FLASH_LOAN_FEE() external view returns (uint256);

    function borrowerOperations() external view returns (IBorrowerOperations);

    function domainSeparator() external view returns (bytes32);

    function factory() external view returns (IFactory);

    function flashFee(address token, uint256 amount) external view returns (uint256);

    function gasPool() external view returns (IGasPool);

    function maxFlashLoan(address token) external view returns (uint256);

    function nonces(address owner) external view returns (uint256);

    function permitTypeHash() external view returns (bytes32);

    function stabilityPool() external view returns (IStabilityPool);

    function troveManager(ITroveManager) external view returns (bool);

    function version() external view returns (string memory);
}

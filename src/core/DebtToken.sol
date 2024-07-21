// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IStabilityPool} from "../interfaces/core/IStabilityPool.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {IFactory} from "../interfaces/core/IFactory.sol";
import {IGasPool} from "../interfaces/core/IGasPool.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {IRewardManager} from "../interfaces/core/IRewardManager.sol";
/**
 * @title Debt Token Contract
 *        Mutated from:
 *        https://github.com/prisma-fi/prisma-contracts/blob/main/contracts/core/DebtToken.sol
 *        https://github.com/liquity/dev/blob/main/packages/contracts/contracts/LUSDToken.sol
 *
 */

contract DebtToken is IDebtToken, SatoshiOwnable, UUPSUpgradeable, ERC20Upgradeable, ERC20PermitUpgradeable {
    string public constant version = "1";

    // --- ERC 3156 Data ---
    bytes32 private constant _RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint256 public constant FLASH_LOAN_FEE = 9; // 1 = 0.0001%

    // --- Addresses ---
    ISatoshiCore private satoshiCore;
    IStabilityPool public stabilityPool;
    IBorrowerOperations public borrowerOperations;
    IFactory public factory;
    IGasPool public gasPool;

    mapping(ITroveManager => bool) public troveManager;

    // Amount of debt to be locked in gas pool on opening troves
    uint256 public DEBT_GAS_COMPENSATION;

    // --- Auth ---
    mapping(address => bool) public wards;

    function rely(address usr) external onlyOwner {
        wards[usr] = true;
    }

    function deny(address usr) external onlyOwner {
        wards[usr] = false;
    }

    modifier auth() {
        require(wards[msg.sender], "DebtToken: not-authorized");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(
        ISatoshiCore _satoshiCore,
        string memory _name,
        string memory _symbol,
        IStabilityPool _stabilityPool,
        IBorrowerOperations _borrowerOperations,
        IFactory _factory,
        IGasPool _gasPool,
        uint256 _gasCompensation
    ) external initializer {
        __SatoshiOwnable_init(_satoshiCore);
        __UUPSUpgradeable_init_unchained();
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);

        stabilityPool = _stabilityPool;
        satoshiCore = _satoshiCore;
        borrowerOperations = _borrowerOperations;
        factory = _factory;
        gasPool = _gasPool;

        DEBT_GAS_COMPENSATION = _gasCompensation;
    }

    function enableTroveManager(ITroveManager _troveManager) external {
        require(msg.sender == address(factory), "!Factory");
        troveManager[_troveManager] = true;
    }

    // --- Functions for intra-Satoshi calls ---

    function mintWithGasCompensation(address _account, uint256 _amount) external returns (bool) {
        require(msg.sender == address(borrowerOperations), "DebtToken: Caller not BorrowerOps");
        _mint(_account, _amount);
        _mint(address(gasPool), DEBT_GAS_COMPENSATION);

        return true;
    }

    function burnWithGasCompensation(address _account, uint256 _amount) external returns (bool) {
        require(msg.sender == address(borrowerOperations), "DebtToken: Caller not BorrowerOps");
        _burn(_account, _amount);
        _burn(address(gasPool), DEBT_GAS_COMPENSATION);

        return true;
    }

    function mint(address _account, uint256 _amount) external {
        require(
            msg.sender == address(borrowerOperations) || troveManager[ITroveManager(msg.sender)] || wards[msg.sender],
            "Debt: Caller not BO/TM/auth"
        );
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external {
        require(troveManager[ITroveManager(msg.sender)] || wards[msg.sender], "Debt: Caller not TroveManager or auth");
        _burn(_account, _amount);
    }

    function sendToSP(address _sender, uint256 _amount) external {
        require(msg.sender == address(stabilityPool), "Debt: Caller not StabilityPool");
        _transfer(_sender, msg.sender, _amount);
    }

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external {
        require(
            msg.sender == address(stabilityPool) || troveManager[ITroveManager(msg.sender)], "Debt: Caller not TM/SP"
        );
        _transfer(_poolAddress, _receiver, _amount);
    }

    // --- External functions ---

    function transfer(address recipient, uint256 amount) public override(IDebtToken, ERC20Upgradeable) returns (bool) {
        _requireValidRecipient(recipient);
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override(IDebtToken, ERC20Upgradeable)
        returns (bool)
    {
        _requireValidRecipient(recipient);
        return super.transferFrom(sender, recipient, amount);
    }

    // --- ERC 3156 Functions ---

    /**
     * @dev Returns the maximum amount of tokens available for loan.
     * @param token The address of the token that is requested.
     * @return The amount of token that can be loaned.
     */
    function maxFlashLoan(address token) public view returns (uint256) {
        return token == address(this) ? type(uint256).max - totalSupply() : 0;
    }

    /**
     * @dev Returns the fee applied when doing flash loans. This function calls
     * the {_flashFee} function which returns the fee applied when doing flash
     * loans.
     * @param token The token to be flash loaned.
     * @param amount The amount of tokens to be loaned.
     * @return The fees applied to the corresponding flash loan.
     */
    function flashFee(address token, uint256 amount) external view returns (uint256) {
        return token == address(this) ? _flashFee(amount) : 0;
    }

    /**
     * @dev Returns the fee applied when doing flash loans. By default this
     * implementation has 0 fees. This function can be overloaded to make
     * the flash loan mechanism deflationary.
     * @param amount The amount of tokens to be loaned.
     * @return The fees applied to the corresponding flash loan.
     */
    function _flashFee(uint256 amount) internal pure returns (uint256) {
        return (amount * FLASH_LOAN_FEE) / 10000;
    }

    /**
     * @dev Performs a flash loan. New tokens are minted and sent to the
     * `receiver`, who is required to implement the {IERC3156FlashBorrower}
     * interface. By the end of the flash loan, the receiver is expected to own
     * amount + fee tokens and have them approved back to the token contract itself so
     * they can be burned.
     * @param receiver The receiver of the flash loan. Should implement the
     * {IERC3156FlashBorrower-onFlashLoan} interface.
     * @param token The token to be flash loaned. Only `address(this)` is
     * supported.
     * @param amount The amount of tokens to be loaned.
     * @param data An arbitrary datafield that is passed to the receiver.
     * @return `true` if the flash loan was successful.
     */
    // This function can reenter, but it doesn't pose a risk because it always preserves the property that the amount
    // minted at the beginning is always recovered and burned at the end, or else the entire function will revert.
    // slither-disable-next-line reentrancy-no-eth
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool)
    {
        require(token == address(this), "ERC20FlashMint: wrong token");
        require(amount <= maxFlashLoan(token), "ERC20FlashMint: amount exceeds maxFlashLoan");
        uint256 fee = _flashFee(amount);
        _mint(address(receiver), amount);
        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == _RETURN_VALUE,
            "ERC20FlashMint: invalid return value"
        );
        _spendAllowance(address(receiver), address(this), amount + fee);
        _burn(address(receiver), amount);

        address rewardManager = satoshiCore.rewardManager();
        _transfer(address(receiver), address(this), fee);
        _approve(address(this), rewardManager, fee);
        IRewardManager(rewardManager).increaseSATPerUintStaked(fee);
        return true;
    }

    // --- 'require' functions ---

    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && _recipient != address(this),
            "Debt: Cannot transfer tokens directly to the Debt token contract or the zero address"
        );
        require(
            _recipient != address(stabilityPool) && !troveManager[ITroveManager(_recipient)]
                && _recipient != address(borrowerOperations),
            "Debt: Cannot transfer tokens directly to the StabilityPool, TroveManager or BorrowerOps"
        );
    }
}

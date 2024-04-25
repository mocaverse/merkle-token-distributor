// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IVersionable } from "../interfaces/IVersionable.sol";
import { ITTUFeeCollector } from "@ethsign/tokentable-evm-contracts/contracts/interfaces/ITTUFeeCollector.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract BaseMerkleDistributor is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IVersionable
{
    using MerkleProof for bytes32[];
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:ethsign.misc.BaseMerkleDistributor
    struct BaseMerkleDistributorStorage {
        mapping(bytes32 leaf => bool used) usedLeafs;
        bytes32 root;
        address token;
        address claimDelegate;
        address feeToken;
        address feeCollector;
        uint256 startTime;
        uint256 endTime;
        bool rootLocked;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.misc.BaseMerkleDistributor")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseMerkleDistributorStorageLocation =
        0x452bdf2c9fe836ad357e55ed0859c19d2ac2a2c151d216523e3d37a8b9a03f00;

    event Initialized(string projectId);
    event RootSet();
    event RootLocked();
    event TokenSet(address token);
    event ClaimDelegateSet(address delegate);
    event TimeSet();
    event FeeTokenSet(address feeToken);
    event FeeCollectorSet(address feeCollector);

    error UnsupportedOperation();
    error RootExpired();
    error RootIsLocked();
    error RootNotLocked();
    error TimeInactive();
    error InvalidProof();
    error LeafUsed();

    function _getBaseMerkleDistributorStorage() internal pure returns (BaseMerkleDistributorStorage storage $) {
        assembly {
            $.slot := BaseMerkleDistributorStorageLocation
        }
    }

    // solhint-disable-next-line ordering
    modifier onlyDelegate() {
        if (_msgSender() != _getBaseMerkleDistributorStorage().claimDelegate) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
        _;
    }

    modifier onlyNotLocked() {
        if (_getBaseMerkleDistributorStorage().rootLocked) revert RootIsLocked();
        _;
    }

    modifier onlyLocked() {
        if (!_getBaseMerkleDistributorStorage().rootLocked) revert RootNotLocked();
        _;
    }

    modifier onlyActive() {
        if (
            block.timestamp < _getBaseMerkleDistributorStorage().startTime
                || block.timestamp > _getBaseMerkleDistributorStorage().endTime
        ) revert TimeInactive();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        if (block.chainid != 31_337) {
            _disableInitializers();
        }
    }

    function initialize(string memory projectId, address owner_) public initializer {
        __Ownable_init(owner_);
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        emit Initialized(projectId);
    }

    function setPause(bool shouldPause) external onlyOwner {
        shouldPause ? _pause() : _unpause();
    }

    function setRoot(bytes32 root, uint256 deadline) external onlyOwner onlyNotLocked {
        if (deadline < block.timestamp) revert RootExpired();
        _getBaseMerkleDistributorStorage().root = root;
        emit RootSet();
    }

    function lockRoot() external onlyOwner {
        _getBaseMerkleDistributorStorage().rootLocked = true;
        emit RootLocked();
    }

    function setToken(address token) external virtual onlyOwner onlyNotLocked {
        _getBaseMerkleDistributorStorage().token = token;
        emit TokenSet(token);
    }

    function setClaimDelegate(address delegate) external onlyOwner {
        _getBaseMerkleDistributorStorage().claimDelegate = delegate;
        emit ClaimDelegateSet(delegate);
    }

    function setStartEndTime(uint256 startTime, uint256 endTime) external onlyOwner onlyNotLocked {
        if (startTime >= endTime) revert UnsupportedOperation();
        _getBaseMerkleDistributorStorage().startTime = startTime;
        _getBaseMerkleDistributorStorage().endTime = endTime;
        emit TimeSet();
    }

    function setHook(address) external virtual onlyOwner onlyNotLocked {
        revert UnsupportedOperation();
    }

    function setFeeToken(address feeToken) external virtual onlyOwner onlyNotLocked {
        _getBaseMerkleDistributorStorage().feeToken = feeToken;
        emit FeeTokenSet(feeToken);
    }

    function setFeeCollector(address feeCollector) external virtual onlyOwner onlyNotLocked {
        _getBaseMerkleDistributorStorage().feeCollector = feeCollector;
        emit FeeCollectorSet(feeCollector);
    }

    function claim(
        bytes32[] calldata proof,
        bytes32 group,
        bytes calldata data
    )
        external
        payable
        virtual
        whenNotPaused
        onlyLocked
        onlyActive
        nonReentrant
    {
        uint256 claimedAmount = _verifyAndClaim(_msgSender(), proof, group, data);
        _afterClaim(_msgSender(), proof, group, data, claimedAmount);
    }

    function delegateClaim(
        address recipient,
        bytes32[] calldata proof,
        bytes32 group,
        bytes calldata data
    )
        external
        payable
        virtual
        whenNotPaused
        onlyDelegate
        onlyLocked
        onlyActive
        nonReentrant
    {
        uint256 claimedAmount = _verifyAndClaim(recipient, proof, group, data);
        _afterDelegateClaim(recipient, proof, group, data, claimedAmount);
    }

    function nuke() external virtual whenPaused onlyOwner {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        $.root = 0;
        $.token = address(0);
        $.claimDelegate = address(0);
        $.startTime = 0;
        $.endTime = 0;
        renounceOwnership();
    }

    // solhint-disable no-empty-blocks
    function withdraw(bytes memory extraData) external virtual { }

    function version() external pure returns (string memory) {
        return "0.1.0";
    }

    function encodeLeaf(address user, bytes32 group, bytes memory data) public view virtual returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), user, group, data));
    }

    function getClaimDelegate() external view returns (address) {
        return _getBaseMerkleDistributorStorage().claimDelegate;
    }

    function getRoot() external view returns (bytes32) {
        return _getBaseMerkleDistributorStorage().root;
    }

    function getRootLocked() external view returns (bool) {
        return _getBaseMerkleDistributorStorage().rootLocked;
    }

    function getTime() external view returns (uint256, uint256) {
        return (_getBaseMerkleDistributorStorage().startTime, _getBaseMerkleDistributorStorage().endTime);
    }

    function getToken() external view returns (address) {
        return _getBaseMerkleDistributorStorage().token;
    }

    function getFeeToken() external view returns (address) {
        return _getBaseMerkleDistributorStorage().feeToken;
    }

    function getFeeCollector() external view returns (address) {
        return _getBaseMerkleDistributorStorage().feeCollector;
    }

    function verify(bytes32[] calldata proof, bytes32 leaf) public view virtual {
        if (isLeafUsed(leaf)) revert LeafUsed();
        if (!proof.verifyCalldata(_getBaseMerkleDistributorStorage().root, leaf)) revert InvalidProof();
    }

    function isLeafUsed(bytes32 leaf) public view virtual returns (bool) {
        return _getBaseMerkleDistributorStorage().usedLeafs[leaf];
    }

    function _verifyAndClaim(
        address recipient,
        bytes32[] calldata proof,
        bytes32 group,
        bytes calldata data
    )
        internal
        virtual
        returns (uint256 claimedAmount);

    function _send(address recipient, address token, uint256 amount) internal virtual;

    function _chargeFees(uint256 claimedAmount) internal virtual {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        if ($.feeCollector == address(0)) return;
        uint256 amountToCharge = ITTUFeeCollector($.feeCollector).getFee(address(this), claimedAmount);
        if ($.feeToken == address(0)) {
            (bool success, bytes memory data) = $.feeCollector.call{ value: amountToCharge }("");
            // solhint-disable-next-line custom-errors
            require(success, string(data));
        } else {
            IERC20($.feeToken).safeTransfer($.feeCollector, amountToCharge);
        }
    }

    function _afterClaim(
        address, // recipient
        bytes32[] calldata, // proof
        bytes32, // group
        bytes calldata, // data
        uint256 claimedAmount
    )
        internal
        virtual
    {
        _chargeFees(claimedAmount);
    }

    function _afterDelegateClaim(
        address, // recipient
        bytes32[] calldata, // proof
        bytes32, // group
        bytes calldata, // data
        uint256 claimedAmount
    )
        internal
        virtual
    {
        _chargeFees(claimedAmount);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner { }
}

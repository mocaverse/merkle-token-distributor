// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IVersionable } from "../interfaces/IVersionable.sol";

abstract contract BaseMerkleDistributor is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IVersionable
{
    using MerkleProof for bytes32[];

    /// @custom:storage-location erc7201:ethsign.misc.BaseMerkleDistributor
    struct BaseMerkleDistributorStorage {
        mapping(bytes32 leaf => bool used) usedLeafs;
        bytes32 root;
        address token;
        address claimDelegate;
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
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        $.root = root;
        emit RootSet();
    }

    function lockRoot() external onlyOwner {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        $.rootLocked = true;
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
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        $.startTime = startTime;
        $.endTime = endTime;
        emit TimeSet();
    }

    function setHook(address) external virtual onlyOwner onlyNotLocked {
        revert UnsupportedOperation();
    }

    function claim(
        bytes32[] calldata proof,
        bytes32 group,
        bytes calldata data
    )
        external
        virtual
        whenNotPaused
        onlyLocked
        onlyActive
        nonReentrant
    {
        _verifyAndClaim(_msgSender(), proof, group, data);
        _afterClaim();
    }

    function delegateClaim(
        address recipient,
        bytes32[] calldata proof,
        bytes32 group,
        bytes calldata data
    )
        external
        virtual
        whenNotPaused
        onlyDelegate
        onlyLocked
        onlyActive
        nonReentrant
    {
        _verifyAndClaim(recipient, proof, group, data);
        _afterDelegateClaim();
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
        return "0.0.2";
    }

    function encodeLeaf(address user, bytes32 group, bytes memory data) public view virtual returns (bytes32) {
        return keccak256(abi.encode(address(this), user, group, data));
    }

    function getClaimDelegate() external view returns (address) {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        return $.claimDelegate;
    }

    function getRoot() external view returns (bytes32) {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        return $.root;
    }

    function getRootLocked() external view returns (bool) {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        return $.rootLocked;
    }

    function getTime() external view returns (uint256, uint256) {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        return ($.startTime, $.endTime);
    }

    function getToken() external view returns (address) {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        return $.token;
    }

    function verify(bytes32[] calldata proof, bytes32 leaf) public view virtual {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        if (isLeafUsed(leaf)) revert LeafUsed();
        if (!proof.verifyCalldata($.root, leaf)) revert InvalidProof();
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
        virtual;

    function _send(address recipient, address token, uint256 amount) internal virtual;

    // solhint-disable-next-line no-empty-blocks
    function _afterClaim() internal virtual { }

    // solhint-disable-next-line no-empty-blocks
    function _afterDelegateClaim() internal virtual { }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner { }
}

// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.23;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

abstract contract BaseMerkleDistributor is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using MerkleProof for bytes32[];

    /// @custom:storage-location erc7201:ethsign.misc.BaseMerkleDistributor
    struct BaseMerkleDistributorStorage {
        bytes32 root;
        uint256 startTime;
        uint256 endTime;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.misc.BaseMerkleDistributor")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseMerkleDistributorStorageLocation =
        0x452bdf2c9fe836ad357e55ed0859c19d2ac2a2c151d216523e3d37a8b9a03f00;

    event RootSet();
    event TimeSet();

    error RootExpired();
    error InvalidProof();
    error LeafUsed();

    function _getBaseMerkleDistributorStorage() internal pure returns (BaseMerkleDistributorStorage storage $) {
        assembly {
            $.slot := BaseMerkleDistributorStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ordering
    constructor() {
        if (block.chainid != 31_337) {
            _disableInitializers();
        }
    }

    function initialize() public initializer {
        __Ownable_init(_msgSender());
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
    }

    function setPause(bool shouldPause) external onlyOwner {
        shouldPause ? _pause() : _unpause();
    }

    function setRoot(bytes32 root, uint256 deadline) external onlyOwner {
        if (deadline < block.timestamp) revert RootExpired();
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        $.root = root;
        emit RootSet();
    }

    function setStartEndTime(uint256 startTime, uint256 endTime) external onlyOwner {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        $.startTime = startTime;
        $.endTime = endTime;
        emit TimeSet();
    }

    function encodeLeaf(address user, bytes32 group, bytes memory data) public view virtual returns (bytes32) {
        return keccak256(abi.encode(address(this), user, group, data));
    }

    function verify(bytes32[] calldata proof, bytes32 leaf) public view virtual {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        if (_isLeafUsed(leaf)) revert LeafUsed();
        if (!proof.verifyCalldata($.root, leaf)) revert InvalidProof();
    }

    function _isLeafUsed(bytes32 leaf) internal view virtual returns (bool);

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner { }
}

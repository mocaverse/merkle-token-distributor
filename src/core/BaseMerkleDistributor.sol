// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.23;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

abstract contract BaseMerkleDistributor is OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using MerkleProof for bytes32[];

    /// @custom:storage-location erc7201:ethsign.misc.basemerkledistributor
    struct BaseMerkleDistributorStorage {
        mapping(string tier => bytes32 root) roots;
        uint256 startTime;
        uint256 endTime;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.misc.basemerkledistributor")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseMerkleDistributorStorageLocation =
        0x997a1691ad6d83c02cec281ee4e92dbc1448725ba15e6bd5035fefbeb754b300;

    event RootSet(string tier);
    event TimeSet();

    error RootExists();
    error InvalidProof();
    error LeafUsed();

    function _getBaseMerkleDistributorStorage() internal pure returns (BaseMerkleDistributorStorage storage $) {
        assembly {
            $.slot := BaseMerkleDistributorStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        if (block.chainid != 31_337) {
            _disableInitializers();
        }
    }

    function initialize() public initializer {
        __Ownable_init(_msgSender());
        __Pausable_init_unchained();
    }

    function setPause(bool shouldPause) external onlyOwner {
        shouldPause ? _pause() : _unpause();
    }

    function setRoot(string calldata tier, bytes32 root) external onlyOwner {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        if ($.roots[tier] != 0) revert RootExists();
        $.roots[tier] = root;
        emit RootSet(tier);
    }

    function setStartEndTime(uint256 startTime, uint256 endTime) external onlyOwner {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        $.startTime = startTime;
        $.endTime = endTime;
        emit TimeSet();
    }

    function generateLeafFor(address user, bytes memory data) public view virtual returns (bytes32);

    function verify(string calldata tier, bytes32[] calldata proof, bytes32 leaf) public view virtual {
        BaseMerkleDistributorStorage storage $ = _getBaseMerkleDistributorStorage();
        if (_isLeafUsed(tier, leaf)) revert LeafUsed();
        if (!proof.verifyCalldata($.roots[tier], leaf)) revert InvalidProof();
    }

    function _isLeafUsed(string calldata tier, bytes32 leaf) internal view virtual returns (bool);

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner { }
}

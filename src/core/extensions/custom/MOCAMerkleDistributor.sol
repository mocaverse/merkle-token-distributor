// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { TokenTableMerkleDistributor, TokenTableMerkleDistributorData } from "../TokenTableMerkleDistributor.sol";
import { DelegateXYZProvider } from "../../../utils/DelegateXYZProvider.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

struct MOCAMerkleDistributorData {
    TokenTableMerkleDistributorData base;
    uint256 expiryTimestamp;
    uint256 nftTokenId;
}

contract MOCAMerkleDistributor is TokenTableMerkleDistributor, DelegateXYZProvider {
    /// @custom:storage-location erc7201:ethsign.misc.MOCAMerkleDistributor
    struct MOCAMerkleDistributorStorage {
        address nft;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.misc.MOCAMerkleDistributor")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MOCAMerkleDistributorStorageLocation =
        0x079e68f457f3a74750d0ad696a5ff6834ab64da74292dbd4ba0e15a12955a000;

    function setNFT(address nft) external onlyOwner {
        MOCAMerkleDistributorStorage storage $ = _getMOCAMerkleDistributorStorage();
        if ($.nft != address(0)) revert UnsupportedOperation();
        $.nft = nft;
    }

    function setClaimDelegate(address) external virtual override {
        revert UnsupportedOperation();
    }

    function batchDelegateClaim(
        address[] calldata,
        bytes32[][] calldata,
        bytes32[] calldata,
        bytes[] calldata
    )
        external
        payable
        virtual
        override
    {
        revert UnsupportedOperation();
    }

    function getNFT() external view returns (address) {
        return _getMOCAMerkleDistributorStorage().nft;
    }

    function delegateClaim(address, bytes32[] calldata, bytes32, bytes calldata) public payable virtual override {
        revert UnsupportedOperation();
    }

    function decodeMOCALeafData(bytes memory data) public pure returns (MOCAMerkleDistributorData memory) {
        return abi.decode(data, (MOCAMerkleDistributorData));
    }

    function decodeLeafData(bytes memory) public pure override returns (TokenTableMerkleDistributorData memory) {
        revert UnsupportedOperation();
    }

    function _verifyAndClaim(
        address,
        bytes32[] calldata proof,
        bytes32 group,
        bytes calldata data
    )
        internal
        override
        returns (uint256 claimedAmount)
    {
        bytes32 leaf = encodeLeaf(address(0), group, data);
        verify(proof, leaf);
        _getBaseMerkleDistributorStorage().usedLeafs[leaf] = true;
        MOCAMerkleDistributorData memory decodedData = decodeMOCALeafData(data);
        if (
            decodedData.base.claimableTimestamp > block.timestamp || decodedData.expiryTimestamp < block.timestamp
                || decodedData.base.claimableTimestamp < _getBaseMerkleDistributorStorage().startTime
        ) revert OutsideClaimableTimeRange();
        address nftOwner = IERC721(_getMOCAMerkleDistributorStorage().nft).ownerOf(decodedData.nftTokenId);
        if (
            nftOwner != _msgSender()
                && !externalDelegateRegistry.checkDelegateForContract(
                    _msgSender(), nftOwner, address(this), this.claim.selector
                )
        ) {
            revert UnsupportedOperation();
        }
        _send(nftOwner, _getBaseMerkleDistributorStorage().token, decodedData.base.claimableAmount);
        return decodedData.base.claimableAmount;
    }

    function _getMOCAMerkleDistributorStorage() internal pure returns (MOCAMerkleDistributorStorage storage $) {
        assembly {
            $.slot := MOCAMerkleDistributorStorageLocation
        }
    }
}

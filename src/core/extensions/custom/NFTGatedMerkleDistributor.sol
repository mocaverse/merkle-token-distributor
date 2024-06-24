// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { TokenTableMerkleDistributor, TokenTableMerkleDistributorData } from "../TokenTableMerkleDistributor.sol";
import { DelegateXYZProvider } from "../../../utils/DelegateXYZProvider.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

import { console } from "forge-std/Test.sol";

struct NFTGatedMerkleDistributorData {
    TokenTableMerkleDistributorData base;
    uint256 expiryTimestamp; // The airdrop can't be claimed past this timestamp. 0 == no expiry.
    uint256 nftTokenId; // Used to infer the eligible claimer (aka current owner or an address authorized by owner
        // through delegate.xyz)
}

contract NFTGatedMerkleDistributor is TokenTableMerkleDistributor, DelegateXYZProvider {
    /// @custom:storage-location erc7201:ethsign.misc.NFTGatedMerkleDistributor
    struct NFTGatedMerkleDistributorStorage {
        address nft;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.misc.NFTGatedMerkleDistributor")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NFTGatedMerkleDistributorStorageLocation =
        0x079e68f457f3a74750d0ad696a5ff6834ab64da74292dbd4ba0e15a12955a000;

    // @dev Sets the NFT token address once
    function setNFT(address nft) external onlyOwner {
        NFTGatedMerkleDistributorStorage storage $ = _getNFTGatedMerkleDistributorStorage();
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
        return _getNFTGatedMerkleDistributorStorage().nft;
    }

    function delegateClaim(address, bytes32[] calldata, bytes32, bytes calldata) public payable virtual override {
        revert UnsupportedOperation();
    }

    // @dev This replaces `decodeLeafData(...)` but needs to be a new function as the return types differ
    function decodeMOCALeafData(bytes memory data) public pure returns (NFTGatedMerkleDistributorData memory) {
        return abi.decode(data, (NFTGatedMerkleDistributorData));
    }

    // @dev Deprecated in favor of `decodeMOCALeafData(...)`
    function decodeLeafData(bytes memory) public pure override returns (TokenTableMerkleDistributorData memory) {
        revert UnsupportedOperation();
    }

    // @dev Disable fee collection for this customization
    // solhint-disable-next-line no-empty-blocks
    function _chargeFees(address, uint256) internal virtual override { }

    function _verifyAndClaim(
        address, // The recipient address is not used since it's inferred from the NFT token owner
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
        NFTGatedMerkleDistributorData memory decodedData = decodeMOCALeafData(data); // Decode with the new function
        if (
            decodedData.base.claimableTimestamp > block.timestamp
                || (decodedData.expiryTimestamp < block.timestamp && decodedData.expiryTimestamp > 0)
                || decodedData.base.claimableTimestamp < _getBaseMerkleDistributorStorage().startTime
        ) revert OutsideClaimableTimeRange();
        address nftOwner = IERC721(_getNFTGatedMerkleDistributorStorage().nft).ownerOf(decodedData.nftTokenId);
        if (
            nftOwner != _msgSender()
                && !externalDelegateRegistry.checkDelegateForContract(
                    _msgSender(), nftOwner, address(this), this.claim.selector
                ) // Checking for delegation using delegate.xyz contract
        ) {
            revert UnsupportedOperation();
        }
        _send(nftOwner, _getBaseMerkleDistributorStorage().token, decodedData.base.claimableAmount);
        return decodedData.base.claimableAmount;
    }

    function _getNFTGatedMerkleDistributorStorage()
        internal
        pure
        returns (NFTGatedMerkleDistributorStorage storage $)
    {
        assembly {
            $.slot := NFTGatedMerkleDistributorStorageLocation
        }
    }
}

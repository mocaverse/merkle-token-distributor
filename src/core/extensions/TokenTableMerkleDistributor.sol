// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.23;

import { BaseMerkleDistributor } from "../BaseMerkleDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct TokenTableMerkleDistributorData {
    uint256 claimableTimestamp;
    uint256 claimableAmount;
}

contract TokenTableMerkleDistributor is BaseMerkleDistributor {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:ethsign.tokentable.MerkleDistributor
    struct TokenTableMerkleDistributorStorage {
        mapping(bytes32 leaf => bool used) usedLeafs;
        IERC20 token;
        address claimDelegate;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.tokentable.MerkleDistributor")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TokenTableMerkleDistributorStorageLocation =
        0xf5bc7bcb6156be57dbd3008b3d0a83a4e3f4cc8216fea5e921f660b3658a8300;

    event Claimed(address recipient, bytes32 group, uint256 amount);
    event ClaimDelegateSet(address delegate);
    event TokenSet(address token);

    error ClaimPremature();

    function _getTokenTableMerkleDistributorStorage()
        internal
        pure
        returns (TokenTableMerkleDistributorStorage storage $)
    {
        assembly {
            $.slot := TokenTableMerkleDistributorStorageLocation
        }
    }

    // solhint-disable-next-line ordering
    function claim(bytes32[] calldata proof, bytes32 group, bytes calldata data) external whenNotPaused nonReentrant {
        _verifyAndClaim(_msgSender(), proof, group, data);
    }

    function delegateClaim(
        address recipient,
        bytes32[] calldata proof,
        bytes32 group,
        bytes calldata data
    )
        external
        whenNotPaused
        nonReentrant
    {
        if (_msgSender() != _getTokenTableMerkleDistributorStorage().claimDelegate) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
        _verifyAndClaim(recipient, proof, group, data);
    }

    function setClaimDelegate(address delegate) external onlyOwner {
        _getTokenTableMerkleDistributorStorage().claimDelegate = delegate;
        emit ClaimDelegateSet(delegate);
    }

    function setToken(address token) external virtual onlyOwner {
        _getTokenTableMerkleDistributorStorage().token = IERC20(token);
        emit TokenSet(token);
    }

    function _verifyAndClaim(
        address recipient,
        bytes32[] calldata proof,
        bytes32 group,
        bytes calldata data
    )
        internal
        virtual
    {
        bytes32 leaf = encodeLeaf(recipient, group, data);
        verify(proof, leaf);
        _getTokenTableMerkleDistributorStorage().usedLeafs[leaf] = true;
        TokenTableMerkleDistributorData memory decodedData = decodeLeafData(data);
        if (decodedData.claimableTimestamp > block.timestamp) revert ClaimPremature();
        _send(recipient, decodedData.claimableAmount);
        emit Claimed(recipient, group, decodedData.claimableAmount);
    }

    function _send(address recipient, uint256 amount) internal virtual {
        _getTokenTableMerkleDistributorStorage().token.safeTransfer(recipient, amount);
    }

    function _isLeafUsed(bytes32 leaf) internal view virtual override returns (bool) {
        return _getTokenTableMerkleDistributorStorage().usedLeafs[leaf];
    }

    function decodeLeafData(bytes memory data) public pure returns (TokenTableMerkleDistributorData memory) {
        return abi.decode(data, (TokenTableMerkleDistributorData));
    }
}

// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { BaseMerkleDistributor } from "../BaseMerkleDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct TokenTableMerkleDistributorData {
    uint256 index;
    uint256 claimableTimestamp;
    uint256 claimableAmount;
}

contract TokenTableMerkleDistributor is BaseMerkleDistributor {
    using SafeERC20 for IERC20;

    event Claimed(address recipient, address token, bytes32 group, uint256 amount);

    error ClaimPremature();

    function withdraw(bytes memory) external virtual override onlyOwner {
        IERC20 token = IERC20(_getBaseMerkleDistributorStorage().token);
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function decodeLeafData(bytes memory data) public pure returns (TokenTableMerkleDistributorData memory) {
        return abi.decode(data, (TokenTableMerkleDistributorData));
    }

    function _verifyAndClaim(
        address recipient,
        bytes32[] calldata proof,
        bytes32 group,
        bytes calldata data
    )
        internal
        override
    {
        bytes32 leaf = encodeLeaf(recipient, group, data);
        verify(proof, leaf);
        _getBaseMerkleDistributorStorage().usedLeafs[leaf] = true;
        TokenTableMerkleDistributorData memory decodedData = decodeLeafData(data);
        if (decodedData.claimableTimestamp > block.timestamp) revert ClaimPremature();
        _send(recipient, _getBaseMerkleDistributorStorage().token, decodedData.claimableAmount);
        emit Claimed(recipient, _getBaseMerkleDistributorStorage().token, group, decodedData.claimableAmount);
    }

    function _send(address recipient, address token, uint256 amount) internal virtual override {
        IERC20(token).safeTransfer(recipient, amount);
    }
}

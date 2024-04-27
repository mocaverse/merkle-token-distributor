// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { TokenTableMerkleDistributor } from "./TokenTableMerkleDistributor.sol";
import { IERC721SafeMintable } from "../../interfaces/IERC721SafeMintable.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

contract SimpleERC721MerkleDistributor is TokenTableMerkleDistributor {
    function withdraw(bytes memory extraData) external virtual override onlyOwner {
        uint256[] memory tokenIds = abi.decode(extraData, (uint256[]));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(_getBaseMerkleDistributorStorage().token).safeTransferFrom(address(this), owner(), tokenIds[i]);
        }
    }

    function _send(address recipient, address token, uint256 amount) internal virtual override {
        for (uint256 i = 0; i < amount; i++) {
            IERC721SafeMintable(token).safeMint(recipient);
        }
    }

    function _balanceOfSelf() internal view virtual override returns (uint256 balance) {
        return IERC721(_getBaseMerkleDistributorStorage().token).balanceOf(address(this));
    }
}

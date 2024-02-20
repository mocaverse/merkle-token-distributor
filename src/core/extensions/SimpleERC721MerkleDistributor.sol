// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.23;

import { TokenTableMerkleDistributor } from "./TokenTableMerkleDistributor.sol";
import { IERC721SafeMintable } from "../../interfaces/IERC721SafeMintable.sol";

contract SimpleERC721MerkleDistributor is TokenTableMerkleDistributor {
    function _send(address recipient, address token, uint256 amount) internal virtual override {
        for (uint256 i = 0; i < amount; i++) {
            IERC721SafeMintable(token).safeMint(recipient);
        }
    }
}

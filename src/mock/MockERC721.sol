// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.23;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { IERC721SafeMintable } from "../interfaces/IERC721SafeMintable.sol";

contract MockERC721 is ERC721Enumerable, IERC721SafeMintable {
    error Unimplemented();

    constructor() ERC721("MockERC721", "MOCK") { }

    function safeMint(address to) external override {
        _safeMint(to, totalSupply());
    }

    function safeMint(address to, uint256 tokenId) external override {
        _safeMint(to, tokenId);
    }
}

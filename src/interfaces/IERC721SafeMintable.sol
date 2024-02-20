// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.23;

interface IERC721SafeMintable {
    function safeMint(address to) external;
    function safeMint(address to, uint256 tokenId) external;
}

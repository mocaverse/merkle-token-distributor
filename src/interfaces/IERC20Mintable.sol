// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.23;

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}

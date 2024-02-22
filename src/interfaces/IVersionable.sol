// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVersionable
 * @author Jack Xu @ EthSign
 */
interface IVersionable {
    function version() external pure returns (string memory);
}

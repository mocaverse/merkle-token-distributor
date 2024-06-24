// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

contract MockDelegateXYZ {
    mapping(
        address to => mapping(address from => mapping(address contract_ => mapping(bytes32 rights => bool approved)))
    ) public rightsMap;
    bool public rightsGlobalOverride;

    constructor() {
        // solhint-disable-next-line custom-errors
        if (block.chainid != 31_337) revert("");
    }

    function setRightsGlobalOverride(bool value) external {
        rightsGlobalOverride = value;
    }

    function setRights(address to, address from, address contract_, bytes32 rights, bool value) external {
        rightsMap[to][from][contract_][rights] = value;
    }

    function checkDelegateForContract(
        address to,
        address from,
        address contract_,
        bytes32 rights
    )
        external
        view
        returns (bool)
    {
        return rightsGlobalOverride ? true : rightsMap[to][from][contract_][rights];
    }
}

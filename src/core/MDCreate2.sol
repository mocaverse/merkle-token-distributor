// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { BaseMerkleDistributor } from "./BaseMerkleDistributor.sol";
import { IVersionable } from "../interfaces/IVersionable.sol";

enum MDType {
    TokenTable,
    TokenTableNative,
    SimpleERC721
}

// solhint-disable max-line-length
contract MDCreate2 is Ownable, IVersionable {
    mapping(string projectId => address deployment) public deployments;
    mapping(MDType mdType => address implementation) public implementations;

    error UnsupportedOperation();

    constructor() Ownable(_msgSender()) { }

    function setImplementation(MDType mdType, address implementation) external onlyOwner {
        implementations[mdType] = implementation;
    }

    function deploy(MDType mdType, string calldata projectId) external returns (address instance) {
        instance = Clones.cloneDeterministic(implementations[mdType], keccak256(abi.encode(projectId)));
        BaseMerkleDistributor(instance).initialize(projectId, _msgSender());
        deployments[projectId] = instance;
    }

    function simulateDeploy(MDType mdType, string calldata projectId) external view returns (address) {
        return
            Clones.predictDeterministicAddress(implementations[mdType], keccak256(abi.encode(projectId)), address(this));
    }

    function version() external pure override returns (string memory) {
        return "0.1.1";
    }
}

// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { BaseMerkleDistributor } from "./BaseMerkleDistributor.sol";
import { IVersionable } from "../interfaces/IVersionable.sol";

// solhint-disable max-line-length
contract MDCreate2 is Ownable, IVersionable {
    mapping(string projectId => address deployment) public deployments;
    mapping(uint8 mdType => address implementation) public implementations;
    mapping(address deployment => address feeTokens) public feeTokens;
    mapping(address deployment => address feeCollectors) public feeCollectors;

    error UnsupportedOperation();

    constructor() Ownable(_msgSender()) { }

    function setDeploymentFeeParams(address deployment, address feeToken, address feeCollector) external onlyOwner {
        feeTokens[deployment] = feeToken;
        feeCollectors[deployment] = feeCollector;
    }

    function setImplementation(uint8 mdType, address implementation) external onlyOwner {
        implementations[mdType] = implementation;
    }

    function deploy(uint8 mdType, string calldata projectId) external returns (address instance) {
        if (deployments[projectId] != address(0)) revert UnsupportedOperation();
        instance = Clones.cloneDeterministic(implementations[mdType], keccak256(abi.encode(projectId)));
        BaseMerkleDistributor(instance).initialize(projectId, _msgSender());
        deployments[projectId] = instance;
    }

    function simulateDeploy(uint8 mdType, string calldata projectId) external view returns (address) {
        return
            Clones.predictDeterministicAddress(implementations[mdType], keccak256(abi.encode(projectId)), address(this));
    }

    function version() external pure override returns (string memory) {
        return "0.3.0";
    }
}

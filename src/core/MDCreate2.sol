// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { BaseMerkleDistributor } from "./BaseMerkleDistributor.sol";
import { TokenTableMerkleDistributor } from "./extensions/TokenTableMerkleDistributor.sol";
import { TokenTableNativeMerkleDistributor } from "./extensions/TokenTableNativeMerkleDistributor.sol";
import { SimpleERC721MerkleDistributor } from "./extensions/SimpleERC721MerkleDistributor.sol";
import { IVersionable } from "../interfaces/IVersionable.sol";

enum MDType {
    TokenTable,
    TokenTableNative,
    SimpleERC721
}

contract MDCreate2 is IVersionable {
    mapping(string projectId => address deployment) public deployments;

    error UnsupportedOperation();

    function deploy(MDType mdType, string calldata projectId) external returns (address instance) {
        bytes memory bytecode = _getBytecodeFromEnum(mdType);
        instance = Create2.deploy(0, keccak256(abi.encode(projectId)), bytecode);
        BaseMerkleDistributor(instance).initialize(projectId);
        deployments[projectId] = instance;
    }

    function simulateDeploy(MDType mdType, string calldata projectId) external view returns (address instance) {
        bytes memory bytecode = _getBytecodeFromEnum(mdType);
        instance = Create2.computeAddress(keccak256(abi.encode(projectId)), keccak256(abi.encodePacked(bytecode)));
    }

    function version() external pure override returns (string memory) {
        return "0.0.2";
    }

    function _getBytecodeFromEnum(MDType mdType) internal pure returns (bytes memory bytecode) {
        if (mdType == MDType.TokenTable) {
            bytecode = type(TokenTableMerkleDistributor).creationCode;
        } else if (mdType == MDType.TokenTableNative) {
            bytecode = type(TokenTableNativeMerkleDistributor).creationCode;
        } else if (mdType == MDType.SimpleERC721) {
            bytecode = type(SimpleERC721MerkleDistributor).creationCode;
        } else {
            revert UnsupportedOperation();
        }
    }
}

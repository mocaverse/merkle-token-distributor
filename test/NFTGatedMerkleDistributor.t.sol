// SPDX-License-Identifier: UNLICENSED
// solhint-disable ordering
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { MDCreate2 } from "../src/core/MDCreate2.sol";
import { TokenTableMerkleDistributorData } from "../src/core/extensions/TokenTableMerkleDistributor.sol";
import {
    NFTGatedMerkleDistributor,
    NFTGatedMerkleDistributorData
} from "../src/core/extensions/custom/NFTGatedMerkleDistributor.sol";
import { Merkle } from "../src/libs/murky/Merkle.sol";
import { MockERC20 } from "../src/mock/MockERC20.sol";
import { MockERC721 } from "../src/mock/MockERC721.sol";
import { MockDelegateXYZ } from "../src/mock/MockDelegateXYZ.sol";
import { IDelegateRegistry } from "../src/libs/delegatexyz/IDelegateRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NFTGatedMerkleDistributorTest is Test {
    using SafeERC20 for IERC20;

    MDCreate2 public deployer;
    NFTGatedMerkleDistributor public instance;
    Merkle public merkleUtil;
    IERC20 public mockErc20;
    IERC721 public mockErc721;
    IDelegateRegistry public mockDelegateXYZ;

    error UnsupportedOperation();
    error TimeInactive();
    error InvalidProof();
    error LeafUsed();
    error IncorrectFees();
    error OutsideClaimableTimeRange();

    function setUp() public {
        deployer = new MDCreate2();
        address impl = address(new NFTGatedMerkleDistributor());
        deployer.setImplementation(3, impl);
        instance = NFTGatedMerkleDistributor(deployer.deploy(3, ""));
        merkleUtil = new Merkle();
        mockErc20 = new MockERC20();
        mockErc721 = new MockERC721();
        vm.etch(0x00000000000000447e69651d841bD8D104Bed493, address(new MockDelegateXYZ()).code);
        mockDelegateXYZ = IDelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493);
    }

    function test_setNft() public {
        instance.setNFT(address(mockErc721));
        assertEq(instance.getNFT(), address(mockErc721));
        vm.expectRevert(UnsupportedOperation.selector);
        instance.setNFT(address(mockErc721));
    }

    function test_disabledFunctions() public {
        vm.expectRevert(UnsupportedOperation.selector);
        instance.setClaimDelegate(address(this));
        vm.expectRevert(UnsupportedOperation.selector);
        instance.batchDelegateClaim(new address[](1), new bytes32[][](1), new bytes32[](1), new bytes[](1));
        vm.expectRevert(UnsupportedOperation.selector);
        instance.delegateClaim(address(this), new bytes32[](1), "", "");
        vm.expectRevert(UnsupportedOperation.selector);
        instance.decodeLeafData("");
    }

    function testFuzz_decodeMOCALeafData(
        uint256 index,
        uint256 claimableTimestamp,
        uint256 claimableAmount,
        uint256 expiryTimestamp,
        uint256 nftTokenId
    )
        public
        view
    {
        TokenTableMerkleDistributorData memory ttData = TokenTableMerkleDistributorData({
            index: index,
            claimableTimestamp: claimableTimestamp,
            claimableAmount: claimableAmount
        });
        NFTGatedMerkleDistributorData memory nftData =
            NFTGatedMerkleDistributorData({ base: ttData, expiryTimestamp: expiryTimestamp, nftTokenId: nftTokenId });
        NFTGatedMerkleDistributorData memory decodedNftData = instance.decodeMOCALeafData(abi.encode(nftData));
        assertEq(nftData.base.claimableAmount, decodedNftData.base.claimableAmount);
        assertEq(nftData.base.claimableTimestamp, decodedNftData.base.claimableTimestamp);
        assertEq(nftData.base.index, decodedNftData.base.index);
        assertEq(nftData.expiryTimestamp, decodedNftData.expiryTimestamp);
        assertEq(nftData.nftTokenId, decodedNftData.nftTokenId);
    }

    function testFuzz_verifyAndClaim(
        address[] memory users,
        bytes32[] memory groups,
        uint256[] memory indexes,
        uint8[] memory claimableTimestampDeltas,
        uint128[] memory claimableAmounts,
        uint8[] memory expiryTimestampDeltas
    )
        public
    {
        vm.assume(
            users.length > 1 && groups.length > 0 && indexes.length > 0 && claimableTimestampDeltas.length > 1
                && claimableAmounts.length > 0 && expiryTimestampDeltas.length > 0
        );
        users[0] = address(123_456_789);
        uint64[] memory claimableTimestamps = new uint64[](users.length);
        claimableTimestamps[0] = claimableTimestampDeltas[0];
        for (uint256 i = 1; i < users.length; i++) {
            if (users[i] == address(0)) users[i] = address(uint160(123_456_789 + i));
            claimableTimestamps[i] =
                claimableTimestamps[i - 1] + claimableTimestampDeltas[i % claimableTimestampDeltas.length];
        }
        (bytes[] memory datas, bytes32[] memory leaves, bytes32 root) =
        _getLeavesAndProofFromDatasetAndMintNFT_uncheckedInput_amount_uint128(
            users, groups, indexes, claimableTimestamps, claimableAmounts, expiryTimestampDeltas
        );
        instance.setBaseParams(address(mockErc20), 0, claimableTimestamps[claimableTimestamps.length - 1] + 1, root);
        instance.setNFT(address(mockErc721));
        for (uint256 i = 0; i < leaves.length; i++) {
            MockERC20(address(mockErc20)).mint(address(instance), claimableAmounts[i % claimableAmounts.length]);
            bytes32[] memory proof = merkleUtil.getProof(leaves, i);
            if (claimableTimestamps[i] > 0) {
                // Block early claims
                vm.warp(claimableTimestamps[i] - 1);
                vm.prank(users[i]);
                vm.expectRevert(abi.encodeWithSelector(OutsideClaimableTimeRange.selector));
                instance.claim(proof, groups[i % groups.length], datas[i]);
            }
            vm.warp(claimableTimestamps[i]);
            // Block non-owner claims
            vm.prank(address(0));
            vm.expectRevert(abi.encodeWithSelector(UnsupportedOperation.selector));
            instance.claim(proof, groups[i % groups.length], datas[i]);
            // Claim normally
            vm.prank(users[i]);
            instance.claim(proof, groups[i % groups.length], datas[i]);
            // Block double-claim attempt
            vm.prank(users[i]);
            vm.expectRevert(abi.encodeWithSelector(LeafUsed.selector));
            instance.claim(proof, groups[i % groups.length], datas[i]);
        }
    }

    function _getLeavesAndProofFromDatasetAndMintNFT_uncheckedInput_amount_uint128(
        address[] memory users,
        bytes32[] memory groups,
        uint256[] memory indexes,
        uint64[] memory claimableTimestamps,
        uint128[] memory claimableAmounts,
        uint8[] memory expiryTimestampDeltas
    )
        internal
        returns (bytes[] memory datas, bytes32[] memory leaves, bytes32 root)
    {
        datas = new bytes[](users.length);
        leaves = new bytes32[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            TokenTableMerkleDistributorData memory ttData = TokenTableMerkleDistributorData({
                index: indexes[i % indexes.length],
                claimableTimestamp: claimableTimestamps[i % claimableTimestamps.length],
                claimableAmount: claimableAmounts[i % claimableAmounts.length]
            });
            NFTGatedMerkleDistributorData memory nftData = NFTGatedMerkleDistributorData({
                base: ttData,
                expiryTimestamp: claimableTimestamps[i % claimableTimestamps.length]
                    + expiryTimestampDeltas[i % expiryTimestampDeltas.length],
                nftTokenId: MockERC721(address(mockErc721)).mint(users[i])
            });
            bytes memory data = abi.encode(nftData);
            leaves[i] = instance.encodeLeaf(address(0), groups[i % groups.length], data);
            datas[i] = data;
        }
        root = merkleUtil.getRoot(leaves);
    }
}

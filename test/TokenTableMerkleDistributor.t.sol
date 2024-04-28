// SPDX-License-Identifier: UNLICENSED
// solhint-disable ordering
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import {
    TokenTableMerkleDistributor,
    TokenTableMerkleDistributorData
} from "../src/core/extensions/TokenTableMerkleDistributor.sol";
import { Merkle } from "../src/libs/murky/Merkle.sol";
import { MockERC20 } from "../src/mock/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenTableMerkleDistributorTest is Test {
    using SafeERC20 for IERC20;

    TokenTableMerkleDistributor public instance;
    Merkle public merkleUtil = new Merkle();
    IERC20 public mockErc20;

    error UnsupportedOperation();
    error TimeInactive();
    error InvalidProof();
    error LeafUsed();

    // Ownable
    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        instance = new TokenTableMerkleDistributor();
        instance.initialize("", address(this));
        mockErc20 = new MockERC20();
    }

    function testFuzz_setBaseParams_fail_badTime(
        address token,
        uint256 startTime,
        uint256 endTime,
        bytes32 root
    )
        public
    {
        vm.assume(startTime >= endTime);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedOperation.selector));
        instance.setBaseParams(token, startTime, endTime, root);
    }

    function testFuzz_setBaseParams_fail_notOwner(
        address notOwner,
        address token,
        uint256 startTime,
        uint256 endTime,
        bytes32 root
    )
        public
    {
        vm.assume(startTime < endTime && notOwner != instance.owner());
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        instance.setBaseParams(token, startTime, endTime, root);
    }

    function testFuzz_setBaseParams_succeed_0(address token, uint256 startTime, uint256 endTime, bytes32 root) public {
        vm.assume(startTime < endTime);
        instance.setBaseParams(token, startTime, endTime, root);
        assertEq(instance.getToken(), token);
        (uint256 contractStartTime, uint256 contractEndTime) = instance.getTime();
        assertEq(contractStartTime, startTime);
        assertEq(contractEndTime, endTime);
        assertEq(instance.getRoot(), root);
    }

    function testFuzz_setFeeParams_fail_notOwner(address notOwner, address feeToken, address feeCollector) public {
        vm.assume(notOwner != address(this));
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        instance.setFeeParams(feeToken, feeCollector);
    }

    function testFuzz_setFeeParams_succeed_0(address feeToken, address feeCollector) public {
        instance.setFeeParams(feeToken, feeCollector);
        assertEq(instance.getFeeToken(), feeToken);
        assertEq(instance.getFeeCollector(), feeCollector);
    }

    function testFuzz_setClaimDelegate_fail_notOwner(address notOwner, address delegate) public {
        vm.assume(notOwner != instance.owner());
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        instance.setClaimDelegate(delegate);
    }

    function testFuzz_setClaimDelegate_succeed_0(address delegate) public {
        instance.setClaimDelegate(delegate);
        assertEq(instance.getClaimDelegate(), delegate);
    }

    function testFuzz_withdraw_fail_notOwner(address notOwner) public {
        vm.assume(notOwner != address(this));
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, notOwner));
        instance.withdraw("");
    }

    function testFuzz_withdraw_succeed_0(uint256 amount) public {
        instance.setBaseParams(address(mockErc20), 0, 1, "");
        _mint(address(instance), amount);
        uint256 balanceBefore = mockErc20.balanceOf(address(this));
        instance.withdraw("");
        uint256 balanceAfter = mockErc20.balanceOf(address(this));
        assertEq(balanceAfter - balanceBefore, amount);
    }

    function testFuzz_decodeLeaf(uint256 index, uint256 claimableTimestamp, uint256 claimableAmount) public view {
        bytes memory data = abi.encode(
            TokenTableMerkleDistributorData({
                index: index,
                claimableTimestamp: claimableTimestamp,
                claimableAmount: claimableAmount
            })
        );
        TokenTableMerkleDistributorData memory dataStruct = instance.decodeLeafData(data);
        assertEq(index, dataStruct.index);
        assertEq(claimableTimestamp, dataStruct.claimableTimestamp);
        assertEq(claimableAmount, dataStruct.claimableAmount);
    }

    function testFuzz_encodeLeaf_verify_no_claim(
        address[] memory users,
        bytes32[] memory groups,
        uint256[] memory indexes,
        uint256[] memory claimableTimestamps,
        uint256[] memory claimableAmounts
    )
        public
    {
        vm.assume(
            users.length > 1 && groups.length > 0 && indexes.length > 0 && claimableTimestamps.length > 0
                && claimableAmounts.length > 0
        );
        (, bytes32[] memory leaves, bytes32 root) =
            _getLeavesAndProofFromDataset_uncheckedInput(users, groups, indexes, claimableTimestamps, claimableAmounts);
        instance.setBaseParams(address(mockErc20), 0, 1, root);
        for (uint256 i = 0; i < leaves.length; i++) {
            bytes32[] memory proof = merkleUtil.getProof(leaves, i);
            instance.verify(proof, leaves[i]);
        }
    }

    function testFuzz_claim_fail_notActive(uint128 startTime, uint128 endTime) public {
        vm.assume(startTime < endTime);
        instance.setBaseParams(address(mockErc20), startTime, endTime, "");
        vm.warp(uint256(endTime) + 1);
        vm.expectRevert(abi.encodeWithSelector(TimeInactive.selector));
        instance.claim(new bytes32[](1), "", "");
    }

    function testFuzz_delegateClaim_fail_notActive(address delegate, uint128 startTime, uint128 endTime) public {
        vm.assume(startTime < endTime);
        instance.setBaseParams(address(mockErc20), startTime, endTime, "");
        instance.setClaimDelegate(delegate);
        vm.warp(uint256(endTime) + 1);
        vm.prank(delegate);
        vm.expectRevert(abi.encodeWithSelector(TimeInactive.selector));
        instance.delegateClaim(address(0), new bytes32[](1), "", "");
    }

    function testFuzz_delegateClaim_fail_notDelegate(address delegate, uint128 startTime, uint128 endTime) public {
        vm.assume(startTime < endTime);
        vm.assume(delegate != address(this));
        instance.setBaseParams(address(mockErc20), startTime, endTime, "");
        instance.setClaimDelegate(delegate);
        vm.warp(endTime - 1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        instance.delegateClaim(address(0), new bytes32[](1), "", "");
    }

    function testFuzz_encodeLeaf_verify_and_claim(
        address[] memory users,
        bytes32[] memory groups,
        uint256[] memory indexes,
        uint64[] memory claimableTimestampDeltas,
        uint128[] memory claimableAmounts
    )
        public
    {
        vm.assume(
            users.length > 1 && groups.length > 0 && indexes.length > 0 && claimableTimestampDeltas.length > 1
                && claimableAmounts.length > 0
        );
        users[0] = address(123_456_789);
        uint256[] memory claimableTimestamps = new uint256[](users.length);
        claimableTimestamps[0] = claimableTimestampDeltas[0];
        for (uint256 i = 1; i < users.length; i++) {
            if (users[i] == address(0)) users[i] = address(123_456_789);
            claimableTimestamps[i] =
                claimableTimestamps[i - 1] + claimableTimestampDeltas[i % claimableTimestampDeltas.length];
        }
        (bytes[] memory datas, bytes32[] memory leaves, bytes32 root) =
        _getLeavesAndProofFromDataset_uncheckedInput_amount_uint128(
            users, groups, indexes, claimableTimestamps, claimableAmounts
        );
        instance.setBaseParams(
            address(mockErc20), claimableTimestamps[0], claimableTimestamps[claimableTimestamps.length - 1] + 1, root
        );
        for (uint256 i = 0; i < leaves.length; i++) {
            _mint(address(instance), claimableAmounts[i % claimableAmounts.length]);
            bytes32[] memory proof = merkleUtil.getProof(leaves, i);
            uint256 balanceBefore = mockErc20.balanceOf(users[i]);
            vm.warp(claimableTimestamps[i]);
            // Block invalid proofs
            vm.prank(address(0));
            vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));
            instance.claim(proof, groups[i % groups.length], datas[i]);
            // Claim normally
            vm.prank(users[i]);
            instance.claim(proof, groups[i % groups.length], datas[i]);
            if (users[i] != address(instance)) {
                assertEq(mockErc20.balanceOf(users[i]) - balanceBefore, claimableAmounts[i % claimableAmounts.length]);
            }
            // Block double-claim attempt
            vm.prank(users[i]);
            vm.expectRevert(abi.encodeWithSelector(LeafUsed.selector));
            instance.claim(proof, groups[i % groups.length], datas[i]);
        }
    }

    function testFuzz_encodeLeaf_verify_and_delegateClaim(
        address delegate,
        address[] memory users,
        bytes32[] memory groups,
        uint256[] memory indexes,
        uint64[] memory claimableTimestampDeltas,
        uint128[] memory claimableAmounts
    )
        public
    {
        vm.assume(
            users.length > 1 && groups.length > 0 && indexes.length > 0 && claimableTimestampDeltas.length > 1
                && claimableAmounts.length > 0
        );
        users[0] = address(123_456_789);
        uint256[] memory claimableTimestamps = new uint256[](users.length);
        claimableTimestamps[0] = claimableTimestampDeltas[0];
        for (uint256 i = 1; i < users.length; i++) {
            if (users[i] == address(0)) users[i] = address(123_456_789);
            claimableTimestamps[i] =
                claimableTimestamps[i - 1] + claimableTimestampDeltas[i % claimableTimestampDeltas.length];
        }
        (bytes[] memory datas, bytes32[] memory leaves, bytes32 root) =
        _getLeavesAndProofFromDataset_uncheckedInput_amount_uint128(
            users, groups, indexes, claimableTimestamps, claimableAmounts
        );
        instance.setBaseParams(
            address(mockErc20), claimableTimestamps[0], claimableTimestamps[claimableTimestamps.length - 1] + 1, root
        );
        instance.setClaimDelegate(delegate);
        for (uint256 i = 0; i < leaves.length; i++) {
            _mint(address(instance), claimableAmounts[i % claimableAmounts.length]);
            bytes32[] memory proof = merkleUtil.getProof(leaves, i);
            uint256 balanceBefore = mockErc20.balanceOf(users[i]);
            vm.warp(claimableTimestamps[i]);
            // Block invalid proofs
            vm.prank(delegate);
            vm.expectRevert(abi.encodeWithSelector(InvalidProof.selector));
            instance.delegateClaim(address(0), proof, groups[i % groups.length], datas[i]);
            // Delegate claim normally
            vm.prank(delegate);
            instance.delegateClaim(users[i], proof, groups[i % groups.length], datas[i]);
            if (users[i] != address(instance)) {
                // if the user is the instance, then the diff will be 0
                assertEq(mockErc20.balanceOf(users[i]) - balanceBefore, claimableAmounts[i % claimableAmounts.length]);
            }
            vm.prank(delegate);
            // Block double-claim attempt
            vm.expectRevert(abi.encodeWithSelector(LeafUsed.selector));
            instance.delegateClaim(users[i], proof, groups[i % groups.length], datas[i]);
        }
    }

    function _mint(address to, uint256 amount) internal {
        MockERC20(address(mockErc20)).mint(to, amount);
    }

    function _getLeavesAndProofFromDataset_uncheckedInput_amount_uint128(
        address[] memory users,
        bytes32[] memory groups,
        uint256[] memory indexes,
        uint256[] memory claimableTimestamps,
        uint128[] memory claimableAmounts
    )
        internal
        view
        returns (bytes[] memory datas, bytes32[] memory leaves, bytes32 root)
    {
        datas = new bytes[](users.length);
        leaves = new bytes32[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            bytes memory data = abi.encode(
                TokenTableMerkleDistributorData({
                    index: indexes[i % indexes.length],
                    claimableTimestamp: claimableTimestamps[i % claimableTimestamps.length],
                    claimableAmount: claimableAmounts[i % claimableAmounts.length]
                })
            );
            leaves[i] = instance.encodeLeaf(users[i], groups[i % groups.length], data);
            datas[i] = data;
        }
        root = merkleUtil.getRoot(leaves);
    }

    function _getLeavesAndProofFromDataset_uncheckedInput(
        address[] memory users,
        bytes32[] memory groups,
        uint256[] memory indexes,
        uint256[] memory claimableTimestamps,
        uint256[] memory claimableAmounts
    )
        internal
        view
        returns (bytes[] memory datas, bytes32[] memory leaves, bytes32 root)
    {
        datas = new bytes[](users.length);
        leaves = new bytes32[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            bytes memory data = abi.encode(
                TokenTableMerkleDistributorData({
                    index: indexes[i % indexes.length],
                    claimableTimestamp: claimableTimestamps[i % claimableTimestamps.length],
                    claimableAmount: claimableAmounts[i % claimableAmounts.length]
                })
            );
            leaves[i] = instance.encodeLeaf(users[i], groups[i % groups.length], data);
            datas[i] = data;
        }
        root = merkleUtil.getRoot(leaves);
    }
}

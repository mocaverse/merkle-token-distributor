// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.20;

import { ITTUFeeCollector, IOwnable } from "../interfaces/ITTUFeeCollector.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TTUFeeCollector is ITTUFeeCollector, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant BIPS_PRECISION = 10 ** 4;
    uint256 public constant MAX_FEE_BIPS = 10 ** 3;

    uint256 public defaultFeesBips;
    mapping(address => uint256) internal _customFeesBips;
    mapping(address => uint256) internal _customFeesFixed;

    constructor() Ownable(_msgSender()) { }

    receive() external payable { }

    function withdrawFee(IERC20 token, uint256 amount) external onlyOwner {
        if (address(token) == address(0)) {
            (bool success, bytes memory data) = owner().call{ value: amount }("");
            // solhint-disable-next-line custom-errors
            require(success, string(data));
        } else {
            token.safeTransfer(owner(), amount);
        }
    }

    function setDefaultFeeBips(uint256 bips) external onlyOwner {
        if (bips > MAX_FEE_BIPS) revert FeesTooHigh();
        defaultFeesBips = bips;
        emit DefaultFeeSetBips(bips);
    }

    // @dev Setting bips to MAX_FEE_BIPS means 0 fees, so technically the MAX_FEE_BIPS is MAX_FEE_BIPS - 1
    function setCustomFeeBips(address unlockerAddress, uint256 bips) external onlyOwner {
        if (bips > MAX_FEE_BIPS) revert FeesTooHigh();
        _customFeesBips[unlockerAddress] = bips;
        emit CustomFeeSetBips(unlockerAddress, bips);
    }

    function setCustomFeeFixed(address unlockerAddress, uint256 fixedFee) external onlyOwner {
        // Not capping a MAX_FEE for fixed fee since it cannot apply equally to all token values
        _customFeesFixed[unlockerAddress] = fixedFee;
        emit CustomFeeSetFixed(unlockerAddress, fixedFee);
    }

    function getFee(
        address unlockerAddress,
        uint256 tokenTransferred
    )
        external
        view
        override
        returns (uint256 tokensCollected)
    {
        uint256 feeFixed = _customFeesFixed[unlockerAddress];
        // If there is a fixed fee, return that fee immediately without checking bips fee
        if (feeFixed > 0) {
            return feeFixed;
        }
        uint256 feeBips = _customFeesBips[unlockerAddress];
        if (feeBips == 0) {
            feeBips = defaultFeesBips;
        } else if (feeBips == MAX_FEE_BIPS) {
            feeBips = 0;
        }
        tokensCollected = (tokenTransferred * feeBips) / BIPS_PRECISION;
    }

    function version() external pure returns (string memory) {
        return "2.6.0";
    }

    function transferOwnership(address newOwner) public override(IOwnable, Ownable) {
        Ownable.transferOwnership(newOwner);
    }

    function renounceOwnership() public override(IOwnable, Ownable) {
        Ownable.renounceOwnership();
    }

    function owner() public view override(IOwnable, Ownable) returns (address) {
        return Ownable.owner();
    }
}

// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { TokenTableMerkleDistributor } from "./TokenTableMerkleDistributor.sol";

contract TokenTableNativeMerkleDistributor is TokenTableMerkleDistributor {
    receive() external payable { }

    function withdraw(bytes memory) external virtual override onlyOwner {
        (bool success, bytes memory data) = owner().call{ value: address(this).balance }("");
        // solhint-disable-next-line custom-errors
        require(success, string(data));
    }

    function setBaseParams(address token, uint256 startTime, uint256 endTime) public virtual override onlyOwner {
        super.setBaseParams(token, startTime, endTime);
        if (token != address(0)) revert UnsupportedOperation();
    }

    function _send(address recipient, address, uint256 amount) internal virtual override {
        (bool success, bytes memory data) = recipient.call{ value: amount }("");
        // solhint-disable-next-line custom-errors
        require(success, string(data));
    }

    function _balanceOfSelf() internal view virtual override returns (uint256 balance) {
        return address(this).balance;
    }
}

// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.23;

import { TokenTableMerkleDistributor } from "./TokenTableMerkleDistributor.sol";

contract TokenTableNativeMerkleDistributor is TokenTableMerkleDistributor {
    error UnsupportedOperation();

    function setToken(address) external virtual override onlyOwner {
        revert UnsupportedOperation();
    }

    function _send(address recipient, address, uint256 amount) internal virtual override {
        (bool success, bytes memory data) = recipient.call{ value: amount }("");
        // solhint-disable-next-line custom-errors
        require(success, string(data));
    }
}

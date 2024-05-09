// SPDX-License-Identifier: AGPL v3
pragma solidity ^0.8.24;

import { IDelegateRegistry } from "../libs/delegatexyz/IDelegateRegistry.sol";

abstract contract DelegateXYZProvider {
    IDelegateRegistry public constant externalDelegateRegistry =
        IDelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        if (
            block.chainid != 1 && block.chainid != 42_161 && block.chainid != 42_170 && block.chainid != 43_114
                && block.chainid != 8453 && block.chainid != 56 && block.chainid != 7700 && block.chainid != 42_220
                && block.chainid != 250 && block.chainid != 100 && block.chainid != 59_144 && block.chainid != 1284
                && block.chainid != 1285 && block.chainid != 10 && block.chainid != 137 && block.chainid != 1101
                && block.chainid != 7_777_777 && block.chainid != 5 && block.chainid != 11_155_111
                && block.chainid != 31_337
        ) {
            // solhint-disable-next-line custom-errors
            revert("Unsupported by delegate.xyz");
        }
    }
}

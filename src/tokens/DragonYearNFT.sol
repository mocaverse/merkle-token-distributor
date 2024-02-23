// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC721AUpgradeable } from "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC721SafeMintable } from "../interfaces/IERC721SafeMintable.sol";

contract DragonYearNFT is OwnableUpgradeable, UUPSUpgradeable, ERC721AUpgradeable, IERC721SafeMintable {
    /// @custom:storage-location erc7201:ethsign.sign.DragonYearNFT
    struct DragonYearNFTStorage {
        address minter;
        string baseURI;
    }

    // keccak256(abi.encode(uint256(keccak256("ethsign.sign.DragonYearNFT")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DragonYearNFTStorageLocation =
        0x44648416f6c415aacc033d34289b4096e031ab4df1d33c82bb884d14267a1d00;

    error UnsupportedOperation();
    error NotMinter();

    function _getDragonYearNFTStorage() internal pure returns (DragonYearNFTStorage storage $) {
        assembly {
            $.slot := DragonYearNFTStorageLocation
        }
    }

    // solhint-disable-next-line ordering
    modifier onlyMinter() {
        if (_msgSender() != _getDragonYearNFTStorage().minter) revert NotMinter();
        _;
    }

    function initialize(string calldata name_, string calldata symbol_) public initializer initializerERC721A {
        __Ownable_init(_msgSender());
        __ERC721A_init_unchained(name_, symbol_);
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _getDragonYearNFTStorage().baseURI = baseURI;
    }

    function setMinter(address minter) external onlyOwner {
        _getDragonYearNFTStorage().minter = minter;
    }

    function safeMint(address to) external onlyMinter {
        _safeMint(to, 1);
    }

    function safeMint(address, uint256) external pure {
        revert UnsupportedOperation();
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner { }

    function _baseURI() internal view virtual override returns (string memory) {
        return _getDragonYearNFTStorage().baseURI;
    }

    function _msgSenderERC721A() internal view override returns (address) {
        return _msgSender();
    }
}

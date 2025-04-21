// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Base is ERC721URIStorage, Ownable {
    // state variables
    uint256 public tokenId;
    string public tokenUri;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        string memory _tokenUri
    ) ERC721(_name, _symbol) Ownable(_owner) {
        tokenUri = _tokenUri;
        _transferOwnership(_owner);
    }

    function mint(address to) external onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenUri);
        tokenId++;
    }
}
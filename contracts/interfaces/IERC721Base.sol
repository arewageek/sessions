// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IERC721Base is IERC721 {
    function mint(address to) external;
}
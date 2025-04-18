// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import {ISessionVideo} from "./interfaces/ISessionVideo.sol";

contract SimpleStorage is ISessionVideo {
    // state variables

    // project wallet
    address public owner;
    address public projectWallet;
    
    // project share percentage
    uint256 public videoCount;
    uint256 public projectSharePercentage;
    
    // mint share percentages
    uint256 public creatorSharePercentage = 60;
    uint256 public projectSharePercentage = 30;
    uint256 public minterSharePercentage = 10;
    

    struct Video {
        address creator;
        string metadataUri;
        string caption;
        uint256 totalMints;
        uint256 mintLimit;
        uint256 price;
        uint256 likes;
        mapping(address => bool) likedBy;
        Comments[] comments;
    }

    struct Creator {
        string name;
        string profileImageUri;
        string bio;
        uint256 totalVideos;
        uint256 totalFollowers;
        uint256 totalTipsReceived;
        SocialMedia socialMedia;
    }

    mapping(uint256 => Video) public videos;
    mapping(address => Creator) public creators;
    mapping(address => mapping(address => bool)) public following;

    // ---------------- modifiers ----------------
    modifier onlyOwner() {
        require(msg.sender == projectWallet, "Not authorized");
        _;
    }
    modifier onlyCreator(uint256 videoId) {
        require(videos[videoId].creator == msg.sender, "Not video creator");
        _;
    }

    constructor(){
        owner = msg.sender;
        projectWallet = msg.sender;
    }

    // --------- internal functions ---------

    function _splitPayment(uint256 _amount, address _creator) internal {
        uint256 projectShare = (_amount * projectSharePercentage) / 100;
        uint256 creatorShare = (_amount * creatorSharePercentage) / 100;
        uint256 minterShare = (_amount * minterSharePercentage) / 100;

        payable(projectWallet).transfer(projectShare);
        payable(_creator).transfer(creatorShare);
        payable(msg.sender).transfer(minterShare);
    }
}
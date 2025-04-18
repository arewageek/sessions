// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import {ISessionVideo} from "./interfaces/ISessionVideo.sol";

contract SessionVideo is ISessionVideo {
    // state variables

    // project wallet
    address public owner;
    address public projectWallet;
    
    // project share percentage
    uint256 public videoCount;
    
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
    mapping(uint => mapping(address => bool)) public likedBy;
    mapping(uint => Comment[]) public comments;

    // ---------------- modifiers ----------------
    modifier onlyOwner() {
        require(msg.sender == projectWallet, "Not authorized");
        _;
    }
    modifier onlyCreator(uint256 videoId) {
        require(videos[videoId].creator == msg.sender, "Not video creator");
        _;
    }
    modifier paidExactMintFee(uint256 _videoId) {
        require(msg.value == videos[_videoId].price, "Incorrect mint fee");
        _;
    }
    modifier videoExists(uint256 _videoId) {
        require(_videoId < videoCount, "Video does not exist");
        _;
    }

    constructor(){
        owner = msg.sender;
        projectWallet = msg.sender;
    }

    // --------- external functions ---------

    // video upload and metadata

    function uploadVideo(
        string memory _metadataUri,
        string memory _caption,
        uint256 _mintLimit,
        uint256 _price
    ) external override {
        videoCount++;
        
        videos[videoCount] = Video({
            creator: msg.sender,
            metadataUri: _metadataUri,
            caption: _caption,
            totalMints: 0,
            mintLimit: _mintLimit,
            price: _price,
            likes: 0
        });

        emit VideoUploaded(videoCount, msg.sender, _metadataUri, _caption, _mintLimit, _price);
    }

    function updateCaption(uint256 _videoId, string calldata _newCaption ) external onlyCreator(_videoId) override {
        videos[_videoId].caption = _newCaption;
        emit CaptionUpdated(_videoId, _newCaption);
    }

    function updateMintLimit( uint256 _videoId, uint256 _newMintLimit ) external override {
        videos[_videoId].mintLimit = _newMintLimit;
        emit MintLimitUpdated(_videoId, _newMintLimit);
    }

    function updatePrice( uint256 _videoId, uint256 _newPrice ) external override {
        videos[_videoId].price = _newPrice;
        emit MintPriceUpdated(_videoId, _newPrice);
    }

    // minting
    function mintVideo(uint256 _videoId) external payable override paidExactMintFee(_videoId){
        Video storage video = videos[_videoId];

        require(video.totalMints < video.mintLimit, "Mint limit reached!");

        video.totalMints ++;
        
        _splitPayment(msg.value, video.creator);

        emit VideoMinted(_videoId, msg.sender, msg.value);
    }

    // engagement
    function likeVideo(uint256 _videoId) external override {
        videos[_videoId].likes ++;
        likedBy[_videoId][msg.sender] = true;

        emit VideoLiked(_videoId, msg.sender);
    }
    function removeLikeFromVideo(uint256 _videoId) external override {
        require(likedBy[_videoId][msg.sender], "Not allowed");

        videos[_videoId].likes --;
        likedBy(_videoId)[msg.sender] = false;
    }
    function commentOnVideo( uint256 _videoId, string memory _commentText ) external override{
        comments[_videoId] = Comment({
            commenter: msg.sender,
            text: _commentText,
            timestamp: block.timestamp
        });

        emit CommentAdded(_videoId, msg.sender, _commentText);
    }

    // tipping of creators
    function tipCreator( uint256 _videoId ) external payable videoExists(_videoId) override {
        require(msg.value > 0, "Invalid tip amount");

        Video memory video = videos[_videoId];
        address creator = video.creator;

        creators[creator].totalTipsReceived += msg.value;

        payable(creator).transfer(msg.value);
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
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISessions {
    // ============ STRUCTS ============
    struct Comment {
        address commenter;
        string text;
        uint256 timestamp;
    }

    struct Video {
        address creator;
        uint256 mediaId;
        uint256 totalMints;
        uint256 mintLimit;
        uint256 price;
        uint256 likes;
    }

    struct Creator {
        string metadataUri;
        uint256 totalVideos;
        uint256 totalFollowers;
        uint256 totalTipsReceived;
    }

    // ============ EVENTS ============
    // Video Management
    event VideoUploaded(uint256 indexed videoId, address indexed creator, uint256 mediaId, uint256 mintLimit, uint256 priceInWei);
    event MintLimitUpdated(uint256 indexed videoId, uint256 newMintLimit);
    event MintPriceUpdated(uint256 indexed videoId, uint256 newPrice);

    // Minting
    event VideoMinted(uint256 indexed videoId, address indexed minter, uint256 price);

    // Social Features
    event VideoLiked(uint256 indexed videoId, address indexed user);
    event VideoUnliked(uint256 indexed videoId, address indexed user);
    event CommentAdded(uint256 indexed videoId, address indexed user, string commentText);
    event CreatorFollowed(address indexed follower, address indexed creator);
    event CreatorUnfollowed(address indexed unfollower, address indexed creator);

    // Creator Management
    event CreatorProfileUpdated(address indexed creator, string metadataUri);
    event CreatorTipped(address indexed tippedBy, address indexed creator, uint256 amount);

    // Admin
    event RevenueSplitUpdated(uint256 projectSharePercentage, uint256 creatorSharePercentage, uint256 minterSharePercentage);
    event FeeUpdated(uint256 newFee);
    event ProjectWalletUpdated(address newWallet);
    event OwnershipTransferred(address indexed prevOwner, address indexed newOwner);
    event GlobalMintLimitUpdated(uint256 newMintLimit);
    event MaxMintPriceUpdated(uint newMintPrice);

    // ============ FUNCTION GROUPS ============

    // ----- Video Management -----
    function uploadVideo(uint256 _mediaId, uint256 _mintLimit, uint256 _priceInWei) external payable;
    function updateMintLimit(uint256 _videoId, uint256 _newMintLimit) external;
    function updateMintPrice(uint256 _videoId, uint256 _newPrice) external;

    // ----- Minting -----
    function mintVideo(uint256 _videoId) external payable;

    // ----- Engagement -----
    function likeVideo(uint256 _videoId) external;
    function unlikeVideo(uint256 _videoId) external;
    function commentOnVideo(uint256 _videoId, string memory _commentText) external;

    // ----- Creator Features -----
    function updateProfile(string memory _metadataUri) external;
    function tipCreator(address _creator) external payable;
    function followCreator(address _creator) external;
    function unfollowCreator(address _creator) external;

    // ----- View Functions -----
    // Video Views
    function hasLikedVideo(uint256 _videoId, address _user) external view returns (bool);
    function getVideoComments(uint256 _videoId) external view returns (Comment[] memory);
    function getTotalComments(uint256 _videoId) external view returns (uint256);
    function getVideoCommentsPaginated(uint256 _videoId, uint256 offset, uint256 limit) external view returns (Comment[] memory);

    // Creator Views
    function getCreatorProfile(address _creator) external view returns (Creator memory);
    function isFollowing(address _follower, address _creator) external view returns (bool);
    function getTotalFollowers(address _creator) external view returns (uint256);

    // Admin Views
    function getBalance() external view returns (uint256);
    function getSharedRevenue() external view returns (uint256[3] memory);

    // ----- Admin Functions -----
    function setProjectWallet(address _projectWallet) external;
    function setRevenueSplit(uint256 _projectShare, uint256 _creatorShare, uint256 _minterShare) external;
    function withdraw() external;
    function setFee(uint _newFee) external;
    function transferOwnership(address _newOwner) external;
}
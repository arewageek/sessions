// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISessionVideo {
    /**
     * Structs
    */

    struct Comment {
        address commenter;
        string text;
        uint256 timestamp;
    }

    struct Video {
        address creator;
        string metadataUri;
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

    /**
     * Events
     */

    // video upload and metadata
    event VideoUploaded(uint256 indexed videoId, address indexed creator, string metadataUri, uint256 mintLimit, uint256 price);
    event MintLimitUpdated(uint256 indexed videoId, uint256 newMintLimit);
    event MintPriceUpdated(uint256 indexed videoId, uint256 newPrice);

    // minting
    event VideoMinted(uint256 indexed videoId, address indexed minter, uint256 price);

    // tipping of creators
    event CreatorTipped(address indexed tippedBy, address indexed creator, uint256 amount, uint256 videoId);

    // engagement
    event VideoLiked(uint256 indexed videoId, address indexed user);
    event VideoUnliked(uint256 indexed videoId, address indexed user);
    event CommentAdded(uint256 indexed videoId, address indexed user, string commentText);

    // creator profile
    event CreatorProfileUpdated(address indexed creator, string metadataUri);
    event CreatorFollowed(address indexed follower, address indexed creator);
    event CreatorUnfollowed(address indexed unfollower, address indexed creator);

    /**
     * Functions
     */

    // video upload and metadata
    function uploadVideo( string memory _metadataUri, uint256 _mintLimit, uint256 _price ) external;
    function updateMintLimit( uint256 _videoId, uint256 _newMintLimit ) external;
    function updatePrice( uint256 _videoId, uint256 _newPrice ) external;

    // minting
    function mintVideo(uint256 _videoId) external payable;

    // engagement
    function likeVideo(uint256 _videoId) external;
    function unlikeVideo(uint256 _videoId) external;
    function commentOnVideo( uint256 _videoId, string memory _commentText ) external;

    // tipping of creators
    function tipCreator( uint256 _videoId ) external payable;

    // view data
    function getVideo(uint256 _videoId) external view returns (Video memory);
    function hasLiked(uint256 _videoId, address _user) external view returns (bool);
    function getVideoComments(uint256 _videoId) external view returns (Comment[] memory);
    function getTotalComments(uint256 _videoId) external view returns (uint256);
    function getVideoCommentsPaginated(uint256 _videoId, uint256 offset, uint256 limit) external view returns (Comment[] memory);

    // creator functions
    function updateProfile(string memory _metadataUri) external;
    function getCreatorProfile( address _creator ) external view returns (Creator memory);

    // following and unfollowing
    function followCreator( address _creator ) external;
    function unfollowCreator( address _creator ) external;
    function isFollowing( address _follower, address _creator ) external view returns (bool);
    function getTotalFollowers( address _creator ) external view returns (uint256);

    // contract admin functions
    function setProjectWallet( address _projectWallet ) external;
    function setRevenueSplit(uint256 _projectSharedPercentage, uint256 _creatorSharedPercentage, uint256 _minterSharedPercentage) external;
    function withdraw() external;
    function setFee(uint _newFee) external;

    // admin view functions
    function getBalance() external view returns (uint256);
}
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

    struct SocialMedia {
        string twitter;
        string telegram;
        string discord;
    }

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

    /**
     * Events
     */

    // video upload and metadata
    event VideoUploaded(uint256 indexed videoId, address indexed creator, string metadataUri, string caption, uint256 mintLimit, uint256 price);
    event CaptionUpdated(uint256 indexed videoId, string newCaption);
    event MintLimitUpdated(uint256 indexed videoId, uint256 newMintLimit);
    event MintPriceUpdated(uint256 indexed videoId, uint256 newPrice);

    // minting
    event VideoMinted(uint256 indexed videoId, address indexed minter, uint256 price);

    // tipping of creators
    event CreatorTipped(address indexed tippedBy, address indexed creator, uint256 amount, uint256 videoId);

    // engagement
    event VideoLiked(uint256 indexed videoId, address indexed user);
    event CommentAdded(uint256 indexed videoId, address indexed user, string commentText);

    // creator profile
    event CreatorProfileUpdated(address indexed creator, string name, string profileImageUri, string bio);
    event CreatorSocialMediaUpdated(address indexed creator, string twitter, string telegram, string discord, string youtube);
    event CreatorFollowed(address indexed follower, address indexed creator);
    event CreatorUnfollowed(address indexed unfollower, address indexed creator);

    /**
     * Functions
     */

    // video upload and metadata
    function uploadVideo( string memory _metadataUri, string memory _caption, uint256 _mintLimit, uint256 _price ) external;
    function updateCaption( uint256 _videoId, string calldata _newCaption ) external;
    function updateMintLimit( uint256 _videoId, uint256 _newMintLimit ) external;
    function updatePrice( uint256 _videoId, uint256 _newPrice ) external;

    // minting
    function mintVideo(uint256 _videoId) external payable;

    // engagement
    function likeVideo(uint256 _videoId) external;
    function removeLikeFromVideo(uint256 _videoId) external;
    function commentOnVideo( uint256 _videoId, string memory _commentText ) external;

    // tipping of creators
    function tipCreator( uint256 _videoId ) external payable;

    // view data
    function getVideo(uint256 _videoId) external view returns (Video memory);
    function getVideoComments(uint256 _videoId) external view returns (Comment[] memory);
    function hasLiked(uint256 _videoId, address _user) external view returns (bool);

    // creator functions
    function updateProfile( string memory _name, string memory _profileImageUri, string memory _bio ) external;
    function updateSocialMedia( string memory _twitter, string memory _telegram, string memory _discord ) external;
    function getCreatorProfile( address _creator ) external view returns (Creator memory);

    // following and unfollowing
    function followCreator( address _creator ) external;
    function unfollowCreator( address _creator ) external;
    function isFollowing( address _creator, address _follower ) external view returns (bool);
    function getTotalFollowers( address _creator ) external view returns (uint256);

    // contract admin functions
    function setProjectWallet( address _projectWallet ) external;
    function setFee(uint256 _projectSharedPercentage, uint256 _creatorSharedPercentage, uint256 _minterSharedPercentage) external;
    function withdraw() external;

    // admin view functions
    function getBalance() external view returns (uint256);
}
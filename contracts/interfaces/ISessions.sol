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
        string ipfsHash;
        uint256 totalMints;
        uint256 mintLimit;
        uint256 price;
        uint256 likes;
        bool isFanit;
        uint256 originalVideoId;
        address fan;
    }

    struct Creator {
        string metadataUri;
        uint256 totalVideos;
        uint256 totalFollowers;
        uint256 totalTipsReceived;
    }

    // ============ EVENTS ============
    // Video Management
    event VideoUploaded(
        uint256 indexed videoId,
        address indexed creator,
        string ipfsHash,
        uint256 mintLimit,
        uint256 priceInWei
    );
    event MintLimitUpdated(uint256 indexed videoId, uint256 newMintLimit);
    event MintPriceUpdated(uint256 indexed videoId, uint256 newPrice);

    // Fanit Events
    event VideoFannited(
        uint256 indexed originalVideoId,
        uint256 indexed fannitVideoId,
        address indexed fan
    );
    event FanitMinted(
        uint256 indexed fannitVideoId,
        address indexed minter,
        uint256 price
    );

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
    event CreatorTipped(
        address indexed tippedBy,
        address indexed creator,
        uint256 amount
    );

    // Admin
    event RevenueSplitUpdated(
        uint256 projectSharePercentage,
        uint256 creatorSharePercentage,
        uint256 minterSharePercentage
    );
    event FanitRevenueSplitUpdated(
        uint256 projectSharePercentage,
        uint256 creatorSharePercentage,
        uint256 fanSharePercentage,
        uint256 minterSharePercentage
    );
    event FeeUpdated(uint256 newFee);
    event ProjectWalletUpdated(address newWallet);
    event OwnershipTransferred(address indexed prevOwner, address indexed newOwner);
    event GlobalMintLimitUpdated(uint256 newMintLimit);
    event MaxMintPriceUpdated(uint newMintPrice);
    event FanitSettingsUpdated(uint256 fannitMintLimit);

    // ============ FUNCTION GROUPS ============

    // ----- Video Management -----
    function uploadVideo(
        string memory _ipfsHash,
        uint256 _mintLimit,
        uint256 _priceInWei
    ) external payable;
    function fannitVideo(uint256 _originalVideoId) external;

    function updateMintLimit(uint256 _videoId, uint256 _newMintLimit) external;
    function updateMintPrice(uint256 _videoId, uint256 _newPrice) external;

    // ----- Minting -----
    function mintVideo(uint256 _videoId) external payable;
    function mintFannit(uint256 _fannitVideoId) external payable;

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
    function getFanitSharedRevenue() external view returns (uint256[4] memory);

    // Fanit Views
    function getFannitsOfVideo(uint256 _videoId) external view returns (uint256[] memory);
    function hasFannited(address _user, uint256 _originalVideoId) external view returns (bool);
    function getFanitMintLimit() external view returns (uint256);

    // ----- Admin Functions -----
    function setProjectWallet(address _projectWallet) external;
    function setRevenueSplit(
        uint256 _projectShare,
        uint256 _creatorShare,
        uint256 _minterShare
    ) external;
    function setFanitRevenueSplit(
        uint256 _projectShare,
        uint256 _creatorShare,
        uint256 _fanShare,
        uint256 _minterShare
    ) external;
    function setFanitMintLimit(uint256 _limit) external;
    function withdraw() external;
    function setFee(uint _newFee) external;
    function transferOwnership(address _newOwner) external;
}

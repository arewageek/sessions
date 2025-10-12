// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISessions} from "./interfaces/ISessions.sol";

contract Sessions is ISessions, ReentrancyGuard {
    // ============ CONTRACT CONFIGURATION ============
    address public owner;
    address public pendingOwner;

    address public projectWallet;

    uint256 public videosCount = 0;
    uint256 public mintLimit = 999999;
    uint256 public maxMintPrice = 1 ether; // 1000000000000000000

    /// @notice Revenue sharing percentages
    uint256 public creatorSharePercentage = 60;
    uint256 public projectSharePercentage = 30;
    uint256 public minterSharePercentage = 10; // treated as discount

    /// @notice Fanit revenue sharing percentages
    uint256 public fanitCreatorSharePercentage = 60;
    uint256 public fanitProjectSharePercentage = 20;
    uint256 public fanitFanSharePercentage = 10;
    uint256 public fanitMinterSharePercentage = 10; // discount

    uint256 public fanitMintLimit = 10;

    uint256 public usdcFee;
    uint public constant USDC_SCALAR = 100; // 100 = 1 USDC, 10 = 0.1 USDC, 1 = 0.01 USDC

    // ============ EXTERNAL DEPENDENCIES ============
    AggregatorV3Interface internal priceFeed;

    // ============ STORAGE ============

    /// @notice Video storage by ID
    mapping(uint256 => Video) public videos; // videoId => Video

    /// @notice Creator profiles by address
    mapping(address => Creator) public creators;

    // socials
    mapping(address => mapping(address => bool)) public following; // user -> creator -> bool
    mapping(uint256 => mapping(address => bool)) public likedBy; // videoId -> user -> bool
    mapping(uint256 => Comment[]) public comments; // videoId => comments

    // fannit tracking
    mapping(uint256 => uint256[]) public fannitsOfVideo; // originalVideoId => array of fannit videoIds
    mapping(address => mapping(uint256 => bool)) public hasFannited; // user -> originalVideoId -> bool

    // uniqueness mapping for IPFS hash -> videoId (0 means not exists)
    mapping(bytes32 => uint256) public videoIdByHash;

    // track mints per user per video (to enforce ownership check when creating fannit)
    mapping(uint256 => mapping(address => uint256)) public balances; // videoId => user => balance

    // ============ ACCESS CONTROL ============
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyCreator(uint256 videoId) {
        require(videos[videoId].creator == msg.sender, "Not authorized");
        _;
    }

    modifier videoExists(uint256 _videoId) {
        require(videos[_videoId].creator != address(0), "Video doesn't exist");
        _;
    }

    modifier isOriginalVideo(uint _videoId){
        require(!videos[_videoId].isFanit, "Not an original");
        _;
    }

    constructor(){
        owner = msg.sender;
        projectWallet = msg.sender;
        usdcFee = 70 * 1e6 / USDC_SCALAR;

        /// @notice Initialize price feed contract address for ETH/USD on Base eth (mainnet)
        priceFeed = AggregatorV3Interface(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);
    }

    // ============ VIDEO MANAGEMENT ============

    /**
     * @notice Upload a new video with minting parameters
     * 
     * @param _ipfsHash Unique media identifier
     * @param _mintLimit Maximum allowed mints
     * @param _priceInWei Mint price in wei
     * 
     * @dev Enforces:
     *      - Valid mint limits (0 < limit <= global max)
     *      - Price bounds (0 < price <= global max)
     *      - Unique ipfs hash
     *      - Non-reentrancy
     */
    function uploadVideo(
        string memory _ipfsHash,
        uint256 _mintLimit,
        uint256 _priceInWei
    ) external override payable nonReentrant {
        uint256 minFee = _getUsdcFeeInEth();
        
        // Validate payment and parameters
        require(msg.value >= minFee, "Insufficient upload fee");

        _validateNewOriginalParams(_ipfsHash, _mintLimit, _priceInWei);
        _createOriginalVideo(_ipfsHash, _mintLimit, _priceInWei, msg.sender);
    }

    /**
     * Create a fannit of an existing *original* video.
     * Requirements:
     * - original must exist and not be a fannit
     * - caller must have minted at least one of the original and still hold it (balances > 0)
     * - caller must not have already fannited the original
     */
    function fannitVideo(uint256 _originalVideoId) external override nonReentrant {
        _validateFannitCreation(_originalVideoId, msg.sender);
        _createFannit(_originalVideoId, msg.sender);
    }

    /**
     * @notice Update a video's mint limit (creator only)
     * 
     * @param _videoId Video ID to update
     * @param _newMintLimit New maximum mint count
     */
    function updateMintLimit(uint256 _videoId, uint256 _newMintLimit) external override onlyCreator(_videoId) isOriginalVideo(_videoId) {
        require(_newMintLimit > 0, "Invalid limit");
        videos[_videoId].mintLimit = _newMintLimit;
        emit MintLimitUpdated(_videoId, _newMintLimit);
    }

    /**
     * @notice Update a video's mint price (creator only)
     * 
     * @param _videoId Video ID to update
     * @param _newPrice New price in wei
     */
    function updateMintPrice(uint256 _videoId, uint256 _newPrice) external override onlyCreator(_videoId) isOriginalVideo(_videoId) {
        require(_newPrice > 0 && _newPrice <= maxMintPrice, "Invalid price");
        videos[_videoId].price = _newPrice;
        emit MintPriceUpdated(_videoId, _newPrice);
    }

     // ============ MINTING (PUBLIC wrappers that call internal split logic) ============

    // minting
    /**
     * @notice Allows users to mint a video NFT by paying the required fee
     * @notice Minting is limited per video (enforced by mintLimit)
     * @notice Payments are automatically split between creator, minter and protocol
     * 
     * @dev    - Requires correct mint fee (paidCorrectMintFee modifier)
     *         - Requires video to exist (videoExists modifier)
     *         - Enforces non-reentrancy protection
     *         - Verifies mint limit not reached
     *         - Processes payment split
     *         - Updates mint counter
     *         - Emits VideoMinted event
     * 
     * @param _videoId The ID of the video being minted
     */
    function mintVideo(uint256 _videoId) external payable override nonReentrant videoExists(_videoId) {
        Video storage video = videos[_videoId];
        require(!video.isFanit, "Use mintFannit for fannits");
        require(video.totalMints < video.mintLimit, "Mint limit reached");

        uint256 price = video.price;
        uint256 minterDiscount = (price * minterSharePercentage) / 100;
        uint256 required = price - minterDiscount;
        require(msg.value >= required, "Incorrect mint fee");

        uint256 creatorShare = (price * creatorSharePercentage) / 100;

        _safeTransfer(payable(video.creator), creatorShare, "Creator payment failed");

        video.totalMints += 1;
        balances[_videoId][msg.sender] += 1;

        emit VideoMinted(_videoId, msg.sender, msg.value);
    }

    /**
     * Mint fannit video
     */
    function mintFannit(uint256 _fannitVideoId) external payable override nonReentrant videoExists(_fannitVideoId) {
        Video storage fannit = videos[_fannitVideoId];
        require(fannit.isFanit, "Not a fannit");
        require(fannit.totalMints < fannit.mintLimit, "Fannit mint limit reached");

        uint256 price = fannit.price;
        uint256 minterDiscount = (price * fanitMinterSharePercentage) / 100;
        uint256 required = price - minterDiscount;
        require(msg.value >= required, "Incorrect mint fee");

        uint256 creatorShare = (price * fanitCreatorSharePercentage) / 100;
        uint256 fanShare = (price * fanitFanSharePercentage) / 100;

        _safeTransfer(payable(fannit.creator), creatorShare, "Creator payment failed");
        _safeTransfer(payable(fannit.fan), fanShare, "Fan payment failed");

        fannit.totalMints += 1;
        balances[_fannitVideoId][msg.sender] += 1;

        emit FanitMinted(_fannitVideoId, msg.sender, msg.value);
    }

    // ============ ENGAGEMENT ============

    /**
     * @notice Allows a user to like a video
     * @notice Each address can like a video only once
     * 
     * @dev    - Requires video to exist (videoExists modifier)
     *         - Enforces non-reentrancy protection
     *         - Prevents duplicate likes
     *         - Updates video like count and user's like status
     *         - Emits VideoLiked event
     * 
     * @param _videoId The ID of the video to like
     */
    function likeVideo(uint256 _videoId) external override videoExists(_videoId) nonReentrant {
        require(! likedBy[_videoId][msg.sender], "video already liked");

        videos[_videoId].likes ++;
        likedBy[_videoId][msg.sender] = true;

        emit VideoLiked(_videoId, msg.sender);
    }


    /**
     * @notice Allows a user to remove their like from a video
     * @dev    - Requires video to exist (videoExists modifier)
     *         - Enforces non-reentrancy protection
     *         - Verifies user has previously liked the video
     *         - Updates like count and user's like status
     *         - Emits VideoUnliked event
     * 
     * @param _videoId The ID of the video to unlike
     */
    function unlikeVideo(uint256 _videoId) external override videoExists(_videoId) nonReentrant {
        require(likedBy[_videoId][msg.sender], "Cannot unlike video");

        videos[_videoId].likes --;
        likedBy[_videoId][msg.sender] = false;

        emit VideoUnliked(_videoId, msg.sender);
    }

    /**
     * @notice Posts a comment on a video
     * @notice Comments are immutable once posted
     * 
     * @dev    - Requires video to exist (enforced by videoExists modifier)
     *         - Stores comment with timestamp and sender address
     *         - Emits CommentAdded event
     * 
     * @param _videoId    The ID of the video being commented on
     * @param _commentText The text content of the comment
     */
    function commentOnVideo(uint256 _videoId, string memory _commentText) external override videoExists(_videoId) {
        Comment memory comment = Comment({
            commenter: msg.sender,
            text: _commentText,
            timestamp: block.timestamp
        });

        comments[_videoId].push(comment);

        emit CommentAdded(_videoId, msg.sender, _commentText);
    }

    // ============ CREATOR FEATURES ============
    
    /**
     * @notice Updates a creator's profile metadata URI
     * @dev Handles both initial profile creation and updates:
     *      - Creates new Creator struct for first-time users
     *      - Updates metadata URI for existing creators
     *      - Emits CreatorProfileUpdated event in both cases
     * 
     * @param _metadataUri IPFS/Arweave URI containing profile metadata (JSON format)
     */
    function updateProfile(string memory _metadataUri) external override {
        if (bytes(creators[msg.sender].metadataUri).length == 0) {
            creators[msg.sender] = Creator({
                metadataUri: _metadataUri,
                totalVideos: 0,
                totalFollowers: 0,
                totalTipsReceived: 0
            });
        }
        else {
            Creator storage creator = creators[msg.sender];
            creator.metadataUri = _metadataUri;
        }
        emit CreatorProfileUpdated(msg.sender, _metadataUri);
    }

    /**
     * @notice Allows users to send tips to creators
     * @dev    - Enforces non-reentrancy protection
     *         - Validates tip amount (> 0) and creator address
     *         - Safely transfers ETH to creator
     *         - Updates creator's lifetime tip counter
     *         - Emits CreatorTipped event
     * 
     * @param _creator The address of the creator to receive the tip
     * @custom:warning Tips are irreversible
     */
    function tipCreator(address _creator) external payable override nonReentrant {
        require(msg.value > 0, "Invalid tip amount");
        require(_creator != address(0), "Invalid creator address");

        _safeTransfer(payable(_creator), msg.value, "Failed to tip creator");

        creators[_creator].totalTipsReceived += msg.value;

        emit CreatorTipped(msg.sender, _creator, msg.value);
    }

    // following and unfollowing
    /**
     * @notice Allows a user to follow a creator
     * @dev    - Enforces non-reentrancy protection
     *         - Prevents self-follows
     *         - Verifies the sender isn't already following
     *         - Updates follower status and increments creator's follower count
     *         - Emits CreatorFollowed event
     * 
     * @param  _creator The address of the creator to follow
     */
    function followCreator(address _creator) external override nonReentrant {
        require(msg.sender != _creator, "Cannot follow self");
        require(!following[msg.sender][_creator], "Already following");

        following[msg.sender][_creator] = true;
        creators[_creator].totalFollowers ++;

        emit CreatorFollowed(msg.sender, _creator);
    }

    /**
     * @notice Allows a user to unfollow a creator
     * @dev    - Enforces non-reentrancy protection
     *         - Verifies the sender is currently following the creator
     *         - Updates follower status and decrements creator's follower count
     *         - Emits CreatorUnfollowed event
     * 
     * @param  _creator The address of the creator to unfollow
     */
    function unfollowCreator(address _creator) external override nonReentrant {
        require(following[msg.sender][_creator], "Not following creator");

        following[msg.sender][_creator] = false;
        creators[_creator].totalFollowers --;

        emit CreatorUnfollowed(msg.sender, _creator);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @notice Checks if a user has liked a specific video
     * 
     * @param _videoId The ID of the video to check
     * @param _user The address of the user to verify
     * 
     * @return bool True if user has liked the video, false otherwise
     */
    function hasLikedVideo(uint256 _videoId, address _user) external view override returns (bool) {
        return likedBy[_videoId][_user];
    }

    /**
     * @notice Retrieves all comments for a specific video
     * 
     * @param _videoId The ID of the video to query comments for
     * @return Comment[] Array of Comment structs
     * @custom:note Returns empty array if video has no comments
     */
    function getVideoComments(uint256 _videoId) external view override returns (Comment[] memory) {
        return comments[_videoId];
    }

    /**
     * @notice Returns the total number of comments for a video
     * 
     * @param _videoId The ID of the video to query
     * @return uint256 The current count of comments
     */
    function getTotalComments(uint256 _videoId) external view override returns (uint256) {
        return comments[_videoId].length;
    }

    /**
     * @notice Retrieves paginated comments for a specific video
     * @dev Handles edge cases for out-of-bounds requests:
     *      - Returns empty array if offset exceeds comment count
     *      - Automatically adjusts end position when limit exceeds remaining comments
     * 
     * @param _videoId The ID of the video to query
     * @param offset Starting index (0-based) for pagination
     * @param limit Maximum number of comments to return
     * @return Comment[] memory Paginated array of Comment structs
     */
    function getVideoCommentsPaginated(uint256 _videoId, uint256 offset, uint256 limit) external view override returns (Comment[] memory) {
        Comment[] storage videoComments = comments[_videoId];
        uint256 total = videoComments.length;

        if (offset >= total){
            return videoComments;
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 size = end - offset;
        Comment[] memory result = new Comment[](size);

        for (uint256 i = 0; i < size; i++){
            result[i] = videoComments[offset + i];
        }

        return result;
    }
    // Creator view

    /**
     * @notice Retrieves a creator's full profile data
     * 
     * @param _creator The address of the creator to query
     * 
     * @return Creator The complete profile struct
     */
    function getCreatorProfile(address _creator) external view override returns (Creator memory) {
        return creators[_creator];
    }

    /**
     * @notice Checks if one address is following another
     * 
     * @param _follower The address to check as follower
     * @param _creator The address to check as content creator
     * 
     * @return bool True if follower follows creator, false otherwise
     */
    function isFollowing(address _follower, address _creator) external view override returns (bool) {
        return following[_follower][_creator];
    }

    /**
     * @notice Returns the total follower count for a creator
     * 
     * @param _creator The address of the creator to query
     * 
     * @return uint256 The current number of followers for this creator
     */
    function getTotalFollowers(address _creator) external view override returns (uint256) {
        return creators[_creator].totalFollowers;
    }

    // Admin Views
    
    /**
     * @notice Fetch total amount of eth stored in the contract
     * 
     * @return uint256 The contract's balance in wei
     */
    function getBalance() external view override returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice returns the shared revenue structure for protocol, creator and minter
     * 
     * @return uint256[3] An array with the order [projectSharePercentage, creatorSharedPercentage, minterSharePercentage]
     */
    function getSharedRevenue() external view override returns (uint256[3] memory) {
        return [
            projectSharePercentage,
            creatorSharePercentage,
            minterSharePercentage
        ];
    }

    function getFanitSharedRevenue() external view override returns (uint256[4] memory) {
        return [
            fanitProjectSharePercentage,
            fanitCreatorSharePercentage,
            fanitFanSharePercentage,
            fanitMinterSharePercentage
        ];
    }

    // Fanit Views
    function getFannitsOfVideo(uint256 _videoId) external view override returns (uint256[] memory) {
        return fannitsOfVideo[_videoId];
    }

    function getFanitMintLimit() external view override returns (uint256) {
        return fanitMintLimit;
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @notice Updates the project's wallet address for receiving revenue shares
     * @dev Can only be called by contract owner. Protects against zero address assignment.
     *      Emits `ProjectWalletUpdated` event on success.
     * 
     * @param _projectWallet The new wallet address (must be non-zero)
     */
    function setProjectWallet(address _projectWallet) external override onlyOwner {
        require(_projectWallet != address(0), "Invalid address");
        projectWallet = _projectWallet;
        emit ProjectWalletUpdated(_projectWallet);
    }

    /**
     * @notice Configures the revenue distribution percentages between project, creator and minter
     * @dev Can only be called by contract owner. Requires sum of percentages to equal 100.
     *      Updates storage and emits `RevenueSplitUpdated` event on success.
     * 
     * @param _projectShare Project's share (0-100, sum must equal 100 with others)
     * @param _creatorShare Creator's share (0-100, sum must equal 100 with others)
     * @param _minterShare Minter's share (0-100, sum must equal 100 with others)
     */
    function setRevenueSplit(
        uint256 _projectShare,
        uint256 _creatorShare,
        uint256 _minterShare
    ) external override onlyOwner {
        require(_projectShare + _creatorShare + _minterShare == 100, "Invalid split ratio");

        projectSharePercentage = _projectShare;
        creatorSharePercentage = _creatorShare;
        minterSharePercentage = _minterShare;

        emit RevenueSplitUpdated(_projectShare, _creatorShare, _minterShare);
    }

    /**
     * @notice Configures the revenue distribution percentages between project, creator and minter
     * @dev Can only be called by contract owner. Requires sum of percentages to equal 100.
     *      Updates storage and emits `RevenueSplitUpdated` event on success.
     * 
     * @param _projectShare Project's share (0-100, sum must equal 100 with others)
     * @param _creatorShare Creator's share (0-100, sum must equal 100 with others)
     * @param _fanShare Fan's share (0-100, sum must equal 100 with others)
     * @param _minterShare Minter's share (0-100, sum must equal 100 with others)
     */
    function setFanitRevenueSplit(
        uint256 _projectShare,
        uint256 _creatorShare,
        uint256 _fanShare,
        uint256 _minterShare
    ) external override onlyOwner {
        require(_projectShare + _creatorShare + _fanShare + _minterShare == 100, "Invalid split ratio");

        fanitProjectSharePercentage = _projectShare;
        fanitCreatorSharePercentage = _creatorShare;
        fanitFanSharePercentage = _fanShare;
        fanitMinterSharePercentage = _minterShare;

        emit FanitRevenueSplitUpdated(_projectShare, _creatorShare, _fanShare, _minterShare);
    }

    function setFanitMintLimit(uint256 _limit) external override onlyOwner {
        require(_limit > 0, "Invalid limit");
        fanitMintLimit = _limit;
        emit FanitSettingsUpdated(_limit);
    }

    /**
     * @notice Initiates ownership transfer to a new address
     * @dev Can only be called by current owner. Sets the pending owner, which must then call `acceptOwnership`.
     *      Protects against zero address assignment.
     * 
     * @param _newOwner The address to nominate as new owner (cannot be zero address)
     */
    function transferOwnership(address _newOwner) external override onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        pendingOwner = _newOwner;
    }

    /**
     * @notice Allows pending owner to accept contract ownership
     * @dev Can only be called by the account set as pending owner. 
     *      Updates contract owner and emits `OwnershipTransferred` event.
     *      Clears the pending owner assignment as part of transfer.
     */
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Not authorized");

        address prevOwner = owner;
        owner = msg.sender;
        pendingOwner = address(0);

        emit OwnershipTransferred(prevOwner, msg.sender);
    }

    /**
     * @notice Updates the global minting limit (callable only by owner)
     * @dev Reverts if new limit is zero or unchanged from current value. 
     *      Emits `GlobalMintLimitUpdated` event on success.
     * 
     * @param _newMintLimit The new maximum number of tokens that can be minted (must be > 0)
     */
    function updateGlobalMintLimit(uint256 _newMintLimit) external onlyOwner {
        require(_newMintLimit > 0 && _newMintLimit != mintLimit, "Invalid mint limit");
        mintLimit = _newMintLimit;
        emit GlobalMintLimitUpdated(_newMintLimit);
    }

    /**
     * @notice Updates the maximum minting price (callable only by owner)
     * @dev Reverts if new price is zero or unchanged from current value. 
     *      Emits `MaxMintPriceUpdated` event on success.
     * 
     * @param _newMaxMintPrice The new maximum mint price (in wei or token units, matching contract's decimal scheme)
     */
    function updateMaximumMintPrice(uint256 _newMaxMintPrice) external onlyOwner {
        require(_newMaxMintPrice > 0 && _newMaxMintPrice != maxMintPrice, "Invalid Mint fee");
        maxMintPrice = _newMaxMintPrice;
        emit MaxMintPriceUpdated(_newMaxMintPrice);
    }

    /**
     * @notice Set's the usdFee added to every transaction (callable only by owner)
     * @dev Reverts if the new fee exceeds 1 USDC (1e6 units). 
     *      Emits a `FeeUpdated` event on success
     * 
     * @param _newFee The usd equivalent multiplied by USD_SCALAR (100)
     */
    function setFee(uint _newFee) external override onlyOwner {
        require(_newFee <= 1e6, "Fee is too high");
        usdcFee = _newFee;
        emit FeeUpdated(_newFee);
    }

    /**
     * @notice Withdraw all tokens from contract to project wallet (callable only by owner)
     */
    function withdraw() external override onlyOwner {
        (bool success, ) = payable(projectWallet).call{value: address(this).balance}("");
        require(success, "withdraw failed");
    }

    // ============ INTERNAL FUNCTIONS ============
    /**
     * Safe transfer wrapper used to make transfers and handle error messages.
     */
    function _safeTransfer(address payable _to, uint256 _amount, string memory _err) internal {
        if (_amount == 0) return;
        (bool ok, ) = _to.call{value: _amount}("");
        require(ok, _err);
    }

    /**
     * Validate the parameters for a new original upload.
     */
    function _validateNewOriginalParams(string memory _ipfsHash, uint256 _mintLimit, uint256 _priceInWei) internal view {
        require(_mintLimit > 0, "Invalid Mint Limit!");
        require(_mintLimit <= mintLimit, "Mint limit too high");
        require(_priceInWei > 0, "Mint price too low!");
        require(_priceInWei <= maxMintPrice, "Mint price too high");
        bytes32 h = keccak256(abi.encodePacked(_ipfsHash));
        require(videoIdByHash[h] == 0, "Video already exists");
    }

    /**
     * Creates and stores a new original video record.
     * Emits VideoUploaded.
     */
    function _createOriginalVideo(string memory _ipfsHash, uint256 _mintLimit, uint256 _priceInWei, address _creator) internal {
        videosCount++;
        uint256 newId = videosCount;

        videos[newId] = Video({
            creator: _creator,
            ipfsHash: _ipfsHash,
            totalMints: 0,
            mintLimit: _mintLimit,
            price: _priceInWei,
            likes: 0,
            isFanit: false,
            originalVideoId: 0,
            fan: address(0)
        });

        bytes32 h = keccak256(abi.encodePacked(_ipfsHash));
        videoIdByHash[h] = newId;

        // increment creator counts if profile exists
        if (bytes(creators[_creator].metadataUri).length != 0) {
            creators[_creator].totalVideos += 1;
        }

        emit VideoUploaded(newId, _creator, _ipfsHash, _mintLimit, _priceInWei);
    }

    /**
     * Validates requirements for creating a fannit.
     */
    function _validateFannitCreation(uint256 _originalVideoId, address _fan) internal view {
        require(videos[_originalVideoId].creator != address(0), "Original doesn't exist");
        require(!videos[_originalVideoId].isFanit, "Cannot fannit a fannit");
        require(!hasFannited[_fan][_originalVideoId], "Already fannited this video");
        require(balances[_originalVideoId][_fan] > 0, "Must own original mint to fannit");
    }

    /**
     * Creates a fannit (internal).
     */
    function _createFannit(uint256 _originalVideoId, address _fan) internal {
        Video storage original = videos[_originalVideoId];

        videosCount++;
        uint256 fannitId = videosCount;

        videos[fannitId] = Video({
            creator: original.creator,
            ipfsHash: original.ipfsHash,
            totalMints: 0,
            mintLimit: fanitMintLimit,
            price: original.price,
            likes: 0,
            isFanit: true,
            originalVideoId: _originalVideoId,
            fan: _fan
        });

        fannitsOfVideo[_originalVideoId].push(fannitId);
        hasFannited[_fan][_originalVideoId] = true;

        emit VideoFannited(_originalVideoId, fannitId, _fan);
    }

    // ============ ORACLE / FEE HELPERS ============

    function getEthPrice() public view returns (uint256) {
        (, int price, , uint256 updatedAt, ) = priceFeed.latestRoundData();

        require(block.timestamp - updatedAt < 1 hours, "Old price");
        require(price > 0, "Invalid price from oracle");

        return uint256(price) * 1e10; // chainlink uses 8 decimals, scale to 18
    }

    function _getUsdcFeeInEth() internal view returns (uint256) {
        uint256 ethPrice = getEthPrice();
        uint256 fixedFeeInEth = usdcFee * 1e30 / ethPrice; // note: mirrors earlier math
        return fixedFeeInEth;
    }

    function getUsdcFeeInEth() public view returns (uint256) {
        return _getUsdcFeeInEth();
    }

    // ============ FALLBACKS ============

    receive() external payable {}

    fallback() external payable {}
}
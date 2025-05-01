// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISessions} from "./interfaces/ISessions.sol";
import "hardhat/console.sol";

contract Sessions is ISessions, ReentrancyGuard {
    // project wallet
    address public owner;
    address public pendingOwner;
    address public projectWallet;
    uint256 public videosCount;
    uint256 public usdcFee;
    uint256 public mintLimit = 999999;
    uint256 public maxMintPrice = 9000000000000000000; // 9 ethers
    // mint share percentages
    uint256 public creatorSharePercentage = 60;
    uint256 public projectSharePercentage = 30;
    uint256 public minterSharePercentage = 10;

    AggregatorV3Interface internal priceFeed;

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
        require(videos[videoId].creator == msg.sender, "Not authorized");
        _;
    }
    modifier paidExactMintFee(uint256 _videoId) {
        // uint fee = getTotalTransferFee(_videoId);
        uint fee = videos[_videoId].price;
        
        require(msg.value >= fee, "Incorrect mint fee");
        _;
    }
    modifier videoExists(uint256 _videoId) {
        require(videos[_videoId].mediaId == _videoId, "Video not exist");
        _;
    }

    constructor(){
        owner = msg.sender;
        projectWallet = msg.sender;
        usdcFee = 7 * 1e17; // 0.7$ worth of base eth
        priceFeed = AggregatorV3Interface(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);
    }

    // video upload and metadata

    function uploadVideo(
        uint256 _mediaId,
        uint256 _mintLimit,
        uint256 _priceInWei
    ) external override nonReentrant() {
        require(_mintLimit > 0, "Invalid Mint Limit!");
        require(_mintLimit < mintLimit, "Mint limit too high");
        require(_priceInWei > 0, "Mint price too low!");
        require(_priceInWei <= maxMintPrice, "Mint price too high");
        require(videos[_mediaId].mediaId == 0 && videos[_mediaId].creator == address(0), "Video already exists!");

        Video memory video = Video({
            creator: msg.sender,
            mediaId: _mediaId,
            totalMints: 0,
            mintLimit: _mintLimit,
            price: _priceInWei,
            likes: 0
        });

        videos[_mediaId] = video;

        emit VideoUploaded(_mediaId, msg.sender, _mediaId, _mintLimit, _priceInWei);
        videosCount++;
    }

    function updateMintLimit( uint256 _videoId, uint256 _newMintLimit ) external onlyCreator(_videoId) override {
        videos[_videoId].mintLimit = _newMintLimit;
        emit MintLimitUpdated(_videoId, _newMintLimit);
    }

    function updateMintPrice( uint256 _videoId, uint256 _newPrice ) external onlyCreator(_videoId) override {
        videos[_videoId].price = _newPrice;
        emit MintPriceUpdated(_videoId, _newPrice);
    }

    // minting
    function mintVideo(uint256 _videoId) external payable override paidExactMintFee(_videoId) videoExists(_videoId) nonReentrant(){
        Video storage video = videos[_videoId];

        require(video.totalMints < video.mintLimit, "Mint limit reached");

        _splitPayment(msg.value, video.creator);

        video.totalMints ++;

        emit VideoMinted(_videoId, msg.sender, msg.value);
    }

    // engagement
    function likeVideo(uint256 _videoId) external videoExists(_videoId) override nonReentrant() {
        require(! likedBy[_videoId][msg.sender], "video already liked");

        videos[_videoId].likes ++;
        likedBy[_videoId][msg.sender] = true;

        emit VideoLiked(_videoId, msg.sender);
    }
    function unlikeVideo(uint256 _videoId) external videoExists(_videoId) override nonReentrant() {
        require(likedBy[_videoId][msg.sender], "Cannot unlike video");

        videos[_videoId].likes --;
        likedBy[_videoId][msg.sender] = false;

        emit VideoUnliked(_videoId, msg.sender);
    }
    function commentOnVideo( uint256 _videoId, string memory _commentText ) external videoExists(_videoId) override{
        Comment memory comment = Comment({
            commenter: msg.sender,
            text: _commentText,
            timestamp: block.timestamp
        });

        comments[_videoId].push(comment);

        emit CommentAdded(_videoId, msg.sender, _commentText);
    }
    function getTotalComments(uint256 _videoId) external view returns (uint256) {
        return comments[_videoId].length;
    }
    function getVideoCommentsPaginated(uint256 _videoId, uint256 offset, uint256 limit) external view returns (Comment[] memory) {
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

    // tipping of creators
    function tipCreator(address _creator) external payable override nonReentrant() {
        require(msg.value > 0, "Invalid tip amount");
        require(_creator != address(0), "Invalid creator address");

        ( bool success, ) = payable(_creator).call{value: msg.value}("");
        require(success, "Failed to tip creator");

        creators[_creator].totalTipsReceived += msg.value;  

        emit CreatorTipped(msg.sender, _creator, msg.value);
    }

    // view data
    function getVideoComments(uint256 _videoId) external view returns (Comment[] memory) {
        return comments[_videoId];
    }
    function hasLikedVideo(uint256 _videoId, address _user) external view returns (bool) {
        return likedBy[_videoId][_user];
    }

    // creator functions
    function updateProfile(string memory _metadataUri) external override {
        if(bytes(creators[msg.sender].metadataUri).length == 0){
            creators[msg.sender] = Creator({
                metadataUri: _metadataUri,
                totalVideos: 0,
                totalFollowers: 0,
                totalTipsReceived: 0
            });
        }
        else{
            Creator storage creator = creators[msg.sender];
            creator.metadataUri = _metadataUri;
        }
        emit CreatorProfileUpdated(msg.sender, _metadataUri);
    }

    function getCreatorProfile( address _creator ) external view returns (Creator memory) {
        return creators[_creator];
    }

    // following and unfollowing
    function followCreator( address _creator ) external nonReentrant() override {
        require(msg.sender != _creator, "Cannot follow self");
        require(!following[msg.sender][_creator], "Already following");

        following[msg.sender][_creator] = true;
        creators[_creator].totalFollowers ++;

        emit CreatorFollowed(msg.sender, _creator);
    }
    function unfollowCreator( address _creator ) external nonReentrant() override {
        require(following[msg.sender][_creator], "Not following creator");

        following[msg.sender][_creator] = false;
        creators[_creator].totalFollowers --;

        emit CreatorUnfollowed(msg.sender, _creator);
    }
    function isFollowing( address _follower, address _creator ) external view returns (bool){
        return following[_follower][_creator];
    }
    function getTotalFollowers( address _creator ) external view returns (uint256){
        return creators[_creator].totalFollowers;
    }

   // contract admin functions
    function setProjectWallet( address _projectWallet ) external onlyOwner() override {
        require(_projectWallet != address(0), "Invalid address");
        projectWallet = _projectWallet;

        emit ProjectWalletUpdated(_projectWallet);
    }
    function setRevenueSplit(
        uint256 _projectSharePercentage,
        uint256 _creatorSharePercentage,
        uint256 _minterSharePercentage
    ) external onlyOwner() override {
        require(_projectSharePercentage + _creatorSharePercentage + _minterSharePercentage == 100, "Invalid split ratio");

        projectSharePercentage = _projectSharePercentage;
        creatorSharePercentage = _creatorSharePercentage;
        minterSharePercentage = _minterSharePercentage;

        emit RevenueSplitUpdated(_projectSharePercentage, _creatorSharePercentage, _minterSharePercentage);
    }
    function transferOwnership (address _newOwner) external onlyOwner() {
        require(_newOwner != address(0), "Invalid address");
        
        pendingOwner = _newOwner;
    }
    function acceptOwnership () external {
        require(msg.sender == pendingOwner, "Not authorized");

        address prevOwner = owner;
        owner = msg.sender;
        
        emit OwnershipTransferred(prevOwner, msg.sender);
    }
    function updateGlobalMintLimit (uint _newMintLimit) external onlyOwner() {
        require(_newMintLimit > 0 && _newMintLimit != mintLimit, "Invalid mint limit");
        mintLimit = _newMintLimit;

        emit GlobalMintLimitUpdated(_newMintLimit);
    }
    function updateMaximumMintPrice (uint _newMaxMintPrice) external onlyOwner() {
        require(_newMaxMintPrice > 0 && _newMaxMintPrice != maxMintPrice, "Invalid Mint fee");
        maxMintPrice = _newMaxMintPrice;

        emit MaxMintPriceUpdated(_newMaxMintPrice);
    }

    function setFee(uint _newFee) external onlyOwner{
        require(_newFee <= 1e6, "Fee is too high");
        usdcFee = _newFee;
        emit FeeUpdated(_newFee);
    }

    function withdraw() external onlyOwner override {
        (bool success, ) = payable(projectWallet).call{value: address(this).balance}("");
        require(success, "withdraw failed");
    }
    // admin view functions
    function getBalance() external view override returns (uint256) {
        return address(this).balance;
    }

    /**
     * Get price of eth
     * 
     * @return uint256
     */
    function getEthPrice() public view returns (uint256) {
        (,int price,,uint256 updatedAt,) = priceFeed.latestRoundData();

        require(block.timestamp - updatedAt < 1 hours, "Old price");
        require(price > 0, "Invalid price from oracle");

        return uint256(price) * 1e10; // chainlink uses 8 decimals
    }

    function getSharedRevenue() external view returns (uint256[3] memory){
        return [
            projectSharePercentage,
            creatorSharePercentage,
            minterSharePercentage
        ];
    }

    function getTotalTransferFee(uint _videoId) public view returns (uint256){
        uint256 ethPrice = getEthPrice();
        uint256 baseFeeInEth = videos[_videoId].price;
        uint256 fixedFeeInEth = usdcFee / ethPrice;
        uint256 totalMintFee = baseFeeInEth + fixedFeeInEth;

        return totalMintFee;
    }

    // --------- internal functions ---------

    function _splitPayment(uint256 _amount, address _creator) internal {
        uint256 creatorShare = (_amount * creatorSharePercentage) / 100;
        uint256 minterShare = (_amount * minterSharePercentage) / 100;

        ( bool creatorSuccess, ) = payable(_creator).call{value: creatorShare}("");
        require(creatorSuccess, "Creator payment failed");

        ( bool minterSuccess, ) = payable(msg.sender).call{value: minterShare}("");
        require(minterSuccess, "Minter payment failed");

    }
}
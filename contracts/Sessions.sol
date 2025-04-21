// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISessions} from "./interfaces/ISessions.sol";

contract Sessions is ISessions, ReentrancyGuard {
    // state variables

    // project wallet
    address public owner;
    address public projectWallet;
    uint256 public videoCount;

    // mint share percentages
    uint256 public creatorSharePercentage = 60;
    uint256 public projectSharePercentage = 30;
    uint256 public minterSharePercentage = 10;

    uint256 usdcFee;

    AggregatorV3Interface priceFeed;

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
        require(msg.value == videos[_videoId].price + getFeeAmountInEth(), "Incorrect mint fee");
        _;
    }
    modifier videoExists(uint256 _videoId) {
        require(_videoId < videoCount, "Video does not exist");
        _;
    }

    constructor(address _chain){
        owner = msg.sender;
        projectWallet = msg.sender;
        usdcFee = 7 * 10**5; // 0.7$ worth of base eth
        priceFeed = AggregatorV3Interface(_chain);
    }

    // --------- external functions ---------

    // video upload and metadata

    function uploadVideo(
        string memory _metadataUri,
        uint256 _mintLimit,
        uint256 _price
    ) external override {
        videos[videoCount] = Video({
            creator: msg.sender,
            metadataUri: _metadataUri,
            totalMints: 0,
            mintLimit: _mintLimit,
            price: _price,
            likes: 0
        });
        videoCount++;

        emit VideoUploaded(videoCount, msg.sender, _metadataUri, _mintLimit, _price);
    }

    function updateMintLimit( uint256 _videoId, uint256 _newMintLimit ) external onlyCreator(_videoId) override {
        videos[_videoId].mintLimit = _newMintLimit;
        emit MintLimitUpdated(_videoId, _newMintLimit);
    }

    function updatePrice( uint256 _videoId, uint256 _newPrice ) external onlyCreator(_videoId) override {
        videos[_videoId].price = _newPrice;
        emit MintPriceUpdated(_videoId, _newPrice);
    }

    // minting
    function mintVideo(uint256 _videoId) external payable override paidExactMintFee(_videoId) videoExists(_videoId) nonReentrant(){
        Video storage video = videos[_videoId];

        require(video.totalMints < video.mintLimit, "Mint limit reached!");

        video.totalMints ++;

        _splitPayment(msg.value, video.creator);

        emit VideoMinted(_videoId, msg.sender, msg.value);
    }

    // engagement
    function likeVideo(uint256 _videoId) external videoExists(_videoId) override nonReentrant() {
        require(! likedBy[_videoId][msg.sender], "Already liked");
        videos[_videoId].likes ++;
        likedBy[_videoId][msg.sender] = true;

        emit VideoLiked(_videoId, msg.sender);
    }
    function unlikeVideo(uint256 _videoId) external videoExists(_videoId) override nonReentrant() {
        require(likedBy[_videoId][msg.sender], "No likes to remove");

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
    function tipCreator( uint256 _videoId ) external payable videoExists(_videoId) override {
        require(msg.value > 0, "Invalid tip amount");

        Video memory video = videos[_videoId];

        creators[video.creator].totalTipsReceived += msg.value;

        payable(video.creator).transfer(msg.value);

        emit CreatorTipped(msg.sender, video.creator, msg.value, _videoId);
    }

    // view data
    function getVideo(uint256 _videoId) external view returns (Video memory video) {
        return videos[_videoId];
    }
    function getVideoComments(uint256 _videoId) external view returns (Comment[] memory) {
        return comments[_videoId];
    }
    function hasLiked(uint256 _videoId, address _user) external view returns (bool) {
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
            creators[msg.sender].metadataUri = _metadataUri;
        }
        emit CreatorProfileUpdated(msg.sender, _metadataUri);
    }

    function getCreatorProfile( address _creator ) external view returns (Creator memory) {
        return creators[_creator];
    }

    // following and unfollowing
    function followCreator( address _creator ) external nonReentrant() override {
        require(msg.sender != _creator, "Cannot follow self");
        require(following[msg.sender][_creator], "Already followed");
        following[msg.sender][_creator] = true;
        creators[_creator].totalFollowers ++;

        emit CreatorFollowed(msg.sender, _creator);
    }
    function unfollowCreator( address _creator ) external nonReentrant() {
        require(following[msg.sender][_creator], "Not following");
        following[msg.sender][_creator] = false;
        creators[_creator].totalFollowers --;
    }
    function isFollowing( address _follower, address _creator ) external view returns (bool){
        return following[_follower][_creator];
    }
    function getTotalFollowers( address _creator ) external view returns (uint256){
        return creators[_creator].totalFollowers;
    }

   // contract admin functions
    function setProjectWallet( address _projectWallet ) external onlyOwner() override{
        projectWallet = _projectWallet;
    }
    function setRevenueSplit(
        uint256 _projectSharedPercentage,
        uint256 _creatorSharedPercentage,
        uint256 _minterSharedPercentage
    ) external onlyOwner override {
        require((_projectSharedPercentage + _creatorSharedPercentage + _minterSharedPercentage) == 100, "Invalid split ratio");
        projectSharePercentage = _projectSharedPercentage;
        creatorSharePercentage = _creatorSharedPercentage;
        minterSharePercentage = _minterSharedPercentage;
    }

    function setFee(uint _newFee) external onlyOwner{
        usdcFee = _newFee;
    }

    function withdraw() external onlyOwner override {
        uint256 balance = address(this).balance;
        _withdraw(projectWallet, balance);
    }

    // admin view functions
    function getBalance() external view override returns (uint256) {
        return address(this).balance;
    }

    // fee related functions
    function getFeeAmountInEth() public view returns (uint256) {
        (,int ethPriceInUSDC,,,) = priceFeed.latestRoundData();
        uint8 decimals = priceFeed.decimals();

        require(ethPriceInUSDC > 0, "Invalid price from oracle");

        uint ethPrice = uint256(ethPriceInUSDC);

        uint256 feeInEth = (usdcFee * 10**(18 + decimals)) / ethPrice;
        return feeInEth;
    }

    // --------- internal functions ---------

    function _splitPayment(uint256 _amount, address _creator) internal {
        require(msg.value == _amount, "Incorrect payment amount");

        uint256 projectShare = (_amount * projectSharePercentage) / 100;
        uint256 creatorShare = (_amount * creatorSharePercentage) / 100;
        uint256 minterShare = (_amount * minterSharePercentage) / 100;

        payable(projectWallet).transfer(projectShare);
        payable(_creator).transfer(creatorShare);
        payable(msg.sender).transfer(minterShare);
    }

    function _withdraw(address _account, uint256 _amount) internal {
        payable(_account).transfer(_amount);
    }
}
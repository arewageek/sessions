// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

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

    uint256 public usdcFee;

    AggregatorV3Interface priceFeed;

    mapping(uint256 => Video) public videos;
    mapping(address => Creator) public creators;
    mapping(address => mapping(address => bool)) public following;
    mapping(uint => mapping(address => bool)) public likedBy;
    mapping(uint => Comment[]) public comments;

    // ---------------- modifiers ----------------
    modifier onlyOwner() {
        require(msg.sender == projectWallet, NotAuthorizedError());
        _;
    }
    modifier onlyCreator(uint256 videoId) {
        require(videos[videoId].creator == msg.sender, NotAuthorizedError());
        _;
    }
    modifier paidExactMintFee(uint256 _videoId) {
        // uint256 feeAmountInEth = getFeeAmountInEth();
        require(msg.value == videos[_videoId].price, IncorrectMintFeeError());
        _;
    }
    modifier videoExists(uint256 _videoId) {
        require(_videoId < videoCount, VideoNotExistError());
        _;
    }

    constructor(address _chain){
        projectWallet = msg.sender;
        usdcFee = 7 * 10**5; // 0.7$ worth of base eth
        priceFeed = AggregatorV3Interface(_chain);
    }

    // --------- external functions ---------

    // video upload and metadata

    function uploadVideo(
        uint256 _mediaId,
        uint256 _mintLimit,
        uint256 _price
    ) external override nonReentrant() {
        videos[videoCount] = Video({
            creator: msg.sender,
            mediaId: _mediaId,
            totalMints: 0,
            mintLimit: _mintLimit,
            price: _price,
            likes: 0
        });

        emit VideoUploaded(videoCount, msg.sender, _mediaId, _mintLimit, _price);
        videoCount++;
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

        require(video.totalMints < video.mintLimit, MintLimitReachedError());

        video.totalMints ++;

        _splitPayment(msg.value, video.creator);

        emit VideoMinted(_videoId, msg.sender, msg.value);
    }

    // engagement
    function likeVideo(uint256 _videoId) external videoExists(_videoId) override nonReentrant() {
        require(! likedBy[_videoId][msg.sender], InvalidVideoEngagementError('like'));
        videos[_videoId].likes ++;
        likedBy[_videoId][msg.sender] = true;

        emit VideoLiked(_videoId, msg.sender);
    }
    function unlikeVideo(uint256 _videoId) external videoExists(_videoId) override nonReentrant() {
        require(likedBy[_videoId][msg.sender], InvalidVideoEngagementError('unlike'));

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
    function tipCreator(address _creator, uint256 _amount) external payable override {
        require(_amount > 0, "Invalid tip amount");

        creators[_creator].totalTipsReceived += msg.value;

        payable(_creator).transfer(_amount);

        emit CreatorTipped(msg.sender, _creator, _amount);
    }

    // view data
    function getVideo(uint256 _videoId) external view returns (Video memory video) {
        return videos[_videoId];
    }
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
            creators[msg.sender].metadataUri = _metadataUri;
        }
        emit CreatorProfileUpdated(msg.sender, _metadataUri);
    }

    function getCreatorProfile( address _creator ) external view returns (Creator memory) {
        return creators[_creator];
    }

    // following and unfollowing
    function followCreator( address _creator ) external nonReentrant() override {
        require(msg.sender != _creator, InvalidFollowingError("Cannot follow self"));
        require(!following[msg.sender][_creator], InvalidFollowingError("Already following"));
        following[msg.sender][_creator] = true;
        creators[_creator].totalFollowers ++;

        emit CreatorFollowed(msg.sender, _creator);
    }
    function unfollowCreator( address _creator ) external nonReentrant() {
        require(following[msg.sender][_creator], InvalidFollowingError("Not following"));
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
        projectWallet = _projectWallet;
    }
    function setRevenueSplit(
        uint256 _projectSharePercentage,
        uint256 _creatorSharePercentage,
        uint256 _minterSharePercentage
    ) external onlyOwner() override {
        require(_projectSharePercentage + _creatorSharePercentage + _minterSharePercentage == 100, InvalidRevenueSplitRatioError());

        projectSharePercentage = _projectSharePercentage;
        creatorSharePercentage = _creatorSharePercentage;
        minterSharePercentage = _minterSharePercentage;

        emit RevenueSplitUpdated(_projectSharePercentage, _creatorSharePercentage, _minterSharePercentage);
    }

    function setFee(uint _newFee) external onlyOwner{
        usdcFee = _newFee;
    }

    function withdraw() external onlyOwner override {
        payable(projectWallet).transfer(address(this).balance);
    }

    // admin view functions
    function getBalance() external view override returns (uint256) {
        return address(this).balance;
    }

    // fee related functions
    function getFeeAmountInEth() public view returns (uint256) {
        (,int ethPriceInUSDC,,,) = priceFeed.latestRoundData();

        require(ethPriceInUSDC > 0, "Invalid price from oracle");

        uint ethPrice = uint256(ethPriceInUSDC);

        uint256 feeInEth = (uint256(usdcFee) * 10**18) / ethPrice;
        return feeInEth;
    }

    function getSharedRevenue() external view returns (uint256[3] memory){
        return [
            projectSharePercentage,
            creatorSharePercentage,
            minterSharePercentage
        ];
    }

    // --------- internal functions ---------

    function _splitPayment(uint256 _amount, address _creator) internal {
        require(msg.value == _amount, "Incorrect payment amount");

        // uint256 projectShare = (_amount * projectSharePercentage) / 100;
        uint256 creatorShare = (_amount * creatorSharePercentage) / 100;
        uint256 minterShare = (_amount * minterSharePercentage) / 100;

        // payable(projectWallet).transfer(projectShare);
        payable(_creator).transfer(creatorShare);
        payable(msg.sender).transfer(minterShare);
    }
}
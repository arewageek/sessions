import { expect } from "chai";
import hre from "hardhat";
import ethers from "ethers";
import viem, { ChainContract, parseEther, WalletClient } from "viem";
import { mintVideo, uploadVideo } from "./helpers";

let owner: WalletClient,
  creator: WalletClient,
  user1: WalletClient,
  user2: WalletClient;
let sessions: ChainContract<"Sessions">;
const ethUsdPriceFeed = "0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70"; // chainlink's price feed CA for ETH/USD on base network
let metadataUri: string;

// video data
let video: string,
  mediaId: bigint,
  totalMints: bigint,
  mintLimit: bigint,
  price: bigint,
  likes: bigint;

describe("Sessions Contract Test", function () {
  before(async () => {
    // get the signers
    [owner, creator, user1, user2] = await hre.viem.getWalletClients();

    // state variables
    mediaId = 0n;
    metadataUri = "https://sample.com";
    totalMints = 0n;
    mintLimit = 10n;
    price = parseEther("0.04");
    likes = 0n;

    // Deploy the contract and get the instances
    sessions = await hre.viem.deployContract("Sessions", []);

    // upload a video
    video = await uploadVideo({
      contract: sessions,
      account: creator.account?.address,
      mediaId,
      mintLimit,
      price,
    });
    mediaId++;

    // simulate a mint
    await mintVideo({
      videoId: 0,
      contract: sessions,
      account: user1.account?.address,
      price,
    });
    totalMints++;
  });

  describe("Contract deployment", function () {
    it("Should deploy contract", async () => {
      expect(sessions.address).to.be.a("string");
    });
  });

  describe("Video Test", function () {
    before(async () => {
      await uploadVideo({
        contract: sessions,
        account: creator.account?.address,
        mediaId,
        mintLimit: 1n,
        price,
      });
      mediaId++;
    });

    describe("Video Upload", function () {
      it("Should upload a video", async () => {
        expect(video).to.be.a("string");
      });

      describe("Mint video", () => {
        it("Should mint video", async () => {
          const mintTx = await mintVideo({
            videoId: 1,
            contract: sessions,
            account: user1.account?.address,
            price,
          });

          const mintCount = await sessions.read.getVideo([1]);

          expect(mintCount.totalMints).to.equal(1n);
        });

        it("Should revert if mint fee is not correct", async () => {
          await expect(
            mintVideo({
              videoId: 1,
              contract: sessions,
              account: user2.account?.address,
              price: parseEther("0.001"),
            })
          ).to.be.rejectedWith("IncorrectMintFeeError");
        });

        it("Should revert if mint limit is reached", async () => {
          await expect(
            mintVideo({
              videoId: 1,
              contract: sessions,
              account: user2.account?.address,
              price: parseEther("0.04"),
            })
          ).to.be.rejectedWith("MintLimitReachedError");
        });
      });
    });
    describe("Update mint limit", function () {
      it("Should update mint limit", async () => {
        await sessions.write.updateMintLimit([1, 5], {
          account: creator.account?.address,
        });

        const videoData = await sessions.read.getVideo([1]);

        expect(videoData.mintLimit).to.equal(5n);
      });

      it("Should revert if caller is not creator", async () => {
        await expect(
          sessions.write.updateMintLimit([0, 2], {
            account: user2.account?.address,
          })
        ).to.be.rejectedWith("NotAuthorized");
      });
    });

    describe("Update Mint price", function () {
      it("Should update mint price", async () => {
        await sessions.write.updateMintPrice([1, parseEther("0.1")], {
          account: creator.account?.address,
        });

        const videoData = await sessions.read.getVideo([1]);

        expect(videoData.price).to.equal(parseEther("0.1"));
      });
      it("Should revert if caller is not creator", async () => {
        await expect(
          sessions.write.updateMintPrice([0, 2], {
            account: user2.account?.address,
          })
        ).to.be.rejectedWith("NotAuthorized");
      });
    });
  });

  describe("Video engagement", function () {
    let prevVideoData: any;

    beforeEach(async () => {
      prevVideoData = await sessions.read.getVideo([1]);
    });
    describe("Like and unlike videos", function () {
      it("Should like video", async () => {
        await sessions.write.likeVideo([1], {
          account: user1.account?.address,
        });

        const newVideoData = await sessions.read.getVideo([1]);

        expect(newVideoData.likes).to.equal(prevVideoData.likes + 1n);
      });

      it("Should revert if video has already been liked by user", async () => {
        await expect(
          sessions.write.likeVideo([1], {
            account: user1.account?.address,
          })
        ).to.be.rejectedWith('InvalidVideoEngagementError("like")');
      });

      it("Should check if user has liked video", async () => {
        const hasLikedFirstVideo = await sessions.read.hasLikedVideo(
          [1, user1.account?.address],
          {
            account: user1.account?.address,
          }
        );

        const hasLikedSecondVideo = await sessions.read.hasLikedVideo(
          [0, user1.account?.address],
          {
            account: user1.account?.address,
          }
        );

        expect(hasLikedFirstVideo).to.be.equal(true);
        expect(hasLikedSecondVideo).to.be.equal(false);
      });

      it("Should unlike video", async () => {
        await sessions.write.unlikeVideo([1], {
          account: user1.account?.address,
        });

        const newVideoData = await sessions.read.getVideo([1]);

        expect(newVideoData.likes).to.equal(prevVideoData.likes - 1n);
      });

      it("Should revert if video unlike is not allowed for user", async () => {
        await expect(
          sessions.write.unlikeVideo([0], {
            account: user1.account?.address,
          })
        ).to.be.rejectedWith('InvalidVideoEngagementError("unlike")');
      });
    });

    describe("Comment on video", function () {
      it("Should drop a comment on video", async () => {
        await sessions.write.commentOnVideo([1, "Nice video!"], {
          account: user1.account?.address,
        });

        const videoCommentsCount = await sessions.read.getTotalComments([1]);

        expect(videoCommentsCount).to.equal(1n);
      });
      it("Should revert if video does not exist", async () => {
        await expect(
          sessions.write.commentOnVideo([8, "Nice video!"], {
            account: user1.account?.address,
          })
        ).to.be.rejectedWith("VideoNotExistError");
      });
    });
  });

  describe("Get video data", function () {
    before(async () => {
      for (let i = 0; i < 10; i++) {
        await sessions.write.commentOnVideo([0, `Nice video! ${i}`], {
          account: user1.account?.address,
        });
      }
    });

    it("Should get total comments count", async () => {
      const commentsCount = await sessions.read.getTotalComments([0]);

      expect(commentsCount).to.be.equal(10n);
    });

    it("Should get video comments paginated", async () => {
      const comments = await sessions.read.getVideoCommentsPaginated([0, 0, 5]);

      expect(comments.length).to.be.equal(5);

      expect(comments[0].text).to.be.equal("Nice video! 0");
      expect(comments[0].commenter.toLowerCase()).to.be.equal(
        user1.account?.address.toLowerCase()
      );

      expect(comments[4].text).to.be.equal("Nice video! 4");
      expect(comments[4].commenter.toLowerCase()).to.be.equal(
        user1.account?.address.toLowerCase()
      );
    });

    it("should get a single video", async () => {
      const video = await sessions.read.getVideo([0]);

      expect(video.creator.toLowerCase()).to.be.equal(
        creator.account?.address.toLowerCase()
      );
      expect(video.mediaId).to.be.equal(0n);
      expect(video.totalMints).to.be.equal(totalMints);
      expect(video.mintLimit).to.be.equal(mintLimit);
      expect(video.price).to.be.equal(price);
      expect(video.likes).to.be.equal(likes);
    });

    it("Should get video comments (not paginated)", async () => {
      const comments = await sessions.read.getVideoComments([0]);

      expect(comments.length).to.be.equal(10);
      expect(comments[0].text).to.be.equal("Nice video! 0");
      expect(comments[0].commenter.toLowerCase()).to.be.equal(
        user1.account?.address.toLowerCase()
      );
      expect(comments[9].text).to.be.equal("Nice video! 9");
      expect(comments[9].commenter.toLowerCase()).to.be.equal(
        user1.account?.address.toLowerCase()
      );
    });
  });

  describe("Creator tests", function () {
    it("Should update creator profile", async () => {
      await sessions.write.updateProfile([metadataUri], {
        account: creator.account?.address,
      });

      const creatorProfile = await sessions.read.getCreatorProfile([
        creator.account?.address,
      ]);

      expect(creatorProfile.metadataUri).to.be.equal(metadataUri);
    });

    it("Should get creator profile", async () => {
      const creatorProfile = await sessions.read.getCreatorProfile([
        creator.account?.address,
      ]);

      expect(creatorProfile.metadataUri).to.be.equal(metadataUri);
    });

    describe("follow or unfollow creator", function () {
      it("Should follow creator", async () => {
        await sessions.write.followCreator([creator.account?.address], {
          account: user1.account?.address,
        });

        const isFollowing = await sessions.read.isFollowing([
          user1.account?.address,
          creator.account?.address,
        ]);

        expect(isFollowing).to.be.equal(true);
      });

      it("Should revert if user is already following creator", async () => {
        await expect(
          sessions.write.followCreator([creator.account?.address], {
            account: user1.account?.address,
          })
        ).to.be.rejectedWith('InvalidFollowingError("Already following")');
      });

      it("Should unfollow creator", async () => {
        await sessions.write.unfollowCreator([creator.account?.address], {
          account: user1.account?.address,
        });

        const isFollowing = await sessions.read.isFollowing([
          user1.account?.address,
          creator.account?.address,
        ]);

        expect(isFollowing).to.be.equal(false);
      });

      it("Should revert if user is not following creator", async () => {
        await expect(
          sessions.write.unfollowCreator([creator.account?.address], {
            account: user1.account?.address,
          })
        ).to.be.rejectedWith('InvalidFollowingError("Not following")');
      });

      it("Should check if user is following creator", async () => {
        const prevIsFollowing = await sessions.read.isFollowing([
          user1.account?.address,
          creator.account?.address,
        ]);

        expect(prevIsFollowing).to.be.equal(false);

        await sessions.write.followCreator([creator.account?.address], {
          account: user1.account?.address,
        });

        const newIsFollowing = await sessions.read.isFollowing([
          user1.account?.address,
          creator.account?.address,
        ]);

        expect(newIsFollowing).to.be.equal(true);
      });

      it("Should get total followers count for creator", async () => {
        const creatorProfile = await sessions.read.getCreatorProfile([
          creator.account?.address,
        ]);

        expect(creatorProfile.totalFollowers).to.be.equal(1n);
      });
    });
  });

  describe("Admin tests", function () {
    it("Should revert if caller is not admin", async () => {
      await expect(
        sessions.write.setFee([1000], {
          account: user1.account?.address,
        })
      ).to.be.rejectedWith("NotAuthorizedError");
    });

    it("Should set revenue split", async () => {
      await sessions.write.setRevenueSplit([0, 0, 100]);

      const sharedRevenue = await sessions.read.getSharedRevenue();

      expect(sharedRevenue).to.deep.equal([0n, 0n, 100n]);
    });

    it("Should revert if total revenue ratio is not 100%", async () => {
      await expect(
        sessions.write.setRevenueSplit([50, 10, 20], {
          account: owner.account?.address,
        })
      ).to.be.rejectedWith("InvalidRevenueSplitRatioError");
    });

    it("Should set fee", async () => {
      await sessions.write.setFee([1000], {
        account: owner.account?.address,
      });
      const fee = await sessions.read.usdcFee({
        account: owner.account?.address,
      });

      expect(fee).to.be.equal(1000n);
    });

    it("Should withdraw funds from contract", async () => {
      await mintVideo({
        videoId: 0,
        contract: sessions,
        account: user2.account?.address,
        price: parseEther("0.04"),
      });

      const prevContractBalance = await sessions.read.getBalance();

      await sessions.write.withdraw([], {
        account: owner.account?.address,
      });
      const newContractBalance = await sessions.read.getBalance({
        account: owner.account?.address,
      });

      expect(prevContractBalance).to.not.equal(parseEther("0"));
      expect(newContractBalance).to.be.equal(parseEther("0"));
    });

    it("Should set project wallet", async () => {
      await sessions.write.setProjectWallet([user1.account?.address], {
        account: owner.account?.address,
      });
      const projectWallet = await sessions.read.projectWallet();

      expect(projectWallet.toLowerCase()).to.equal(
        user1.account?.address.toLowerCase()
      );
    });
  });

  describe("Test chainlink oracle", function () {
    it("Should return eth price and timestamp", async function () {
      const response = await sessions.read.getEthPriceFromChainlink();
      console.log({ response });
    });
  });
});

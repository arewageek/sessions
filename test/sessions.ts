import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseGwei } from "viem";

describe("Sessions Contract Test", function () {
  beforeEach(async function () {
    //
  });

  describe("Video Test", function () {
    describe("Video Upload", function () {
      it("Should upload a video", async function () {
        //
      });

      it("Should mint video", async function () {
        //
      });

      it("Should revert if mint fee is not correct", async function () {
        //
      });

      it("Should revert if mint limit is reached", async function () {
        //
      });
    });
    describe("Update mint limit", function () {
      it("Should update mint limit", async function () {
        //
      });

      it("Should revert if caller is not creator", async function () {
        //
      });
    });

    describe("Update Mint price", function () {
      it("Should update mint price", async function () {
        //
      });
    });
  });

  describe("Video engagement", function () {
    describe("Like and unlike videos", function () {
      it("Should like video", async function () {
        //
      });

      it("Should rever if video has already been liked by user", async function () {
        //
      });

      it("Should unlike video", async function () {
        //
      });

      it("Should revert if video unlike is not allowed", async function () {
        //
      });

      it("Should check if user has liked video", async function () {
        //
      });
    });

    describe("Comment on video", function () {
      it("Should drop a comment on video", async function () {
        //
      });
      it("Should revert if video does not exist", async function () {
        //
      });
    });
  });

  describe("Get video data", function () {
    it("Should get total comments", async function () {
      //
    });

    it("Should get video comments paginated", async function () {
      //
    });

    it("should get a single video", async function () {
      //
    });

    it("Should get video comments (not paginated)", async function () {
      //
    });
  });

  describe("Creator tests", function () {
    it("Should update creator profile", async function () {
      //
    });

    it("Should get creator profile", async function () {
      //
    });

    describe("follow or unfollow creator", function () {
      it("Should follow creator", async function () {
        //
      });

      it("Should revert if user is already following creator", async function () {
        //
      });

      it("Should unfollow creator", async function () {
        //
      });

      it("Should revert if user is not following creator", async function () {
        //
      });

      it("Should check if user is following creator", async function () {
        //
      });

      it("Should get total followers count for creator", async function () {
        //
      });
    });
  });

  describe("Contract admin tests", function () {
    it("Should revert if caller is not admin", async function () {
      //
    });

    it("Should set project wallet", async function () {
      //
    });

    it("Should set project wallet", async function () {
      //
    });

    it("Should set revenue split", async function () {
      //
    });

    it("Should set fee", async function () {
      //
    });

    it("Should withdraw funds from contract", async function () {
      //
    });

    it("Should get token balance on contract", async function () {
      //
    });
  });
});

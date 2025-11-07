import { ChainContract } from "viem";

interface IVideoData {
  contract: ChainContract<"Sessions">;
  account: `0x${string}` | undefined;
  price: bigint;
}

interface MintVideoArgs extends IVideoData {
  videoId: number;
}

interface UploadVideoArgs extends IVideoData {
  mintLimit: number;
  mediaId: number;
}

export const uploadVideo = async ({
  contract,
  account,
  mediaId,
  mintLimit,
  price,
}: UploadVideoArgs) => {
  return await contract.write.uploadVideo([mediaId, mintLimit, price], {
    account,
  });
};

export const mintVideo = async ({
  videoId,
  account,
  contract,
  price,
}: MintVideoArgs) => {
  return await contract.write.mintVideo([videoId], {
    account,
    value: price,
  });
};

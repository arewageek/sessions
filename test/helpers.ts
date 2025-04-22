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
  mintLimit: bigint;
  metadataUri: string;
}

export const mintVideo = async ({
  videoId,
  contract,
  account,
  price,
}: MintVideoArgs) => {
  return await contract.write.mintVideo([videoId], {
    account,
    value: price,
  });
};

export const uploadVideo = async ({
  contract,
  account,
  metadataUri,
  mintLimit,
  price,
}: UploadVideoArgs) => {
  return await contract.write.uploadVideo([metadataUri, mintLimit, price], {
    account,
  });
};

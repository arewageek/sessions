import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SessionsModule = buildModule("SessionsModule", (m) => {
  const sessions = m.contract("Sessions", [
    "0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70", // chainlink's price feed CA for ETH/USD on base network
  ]);

  return { sessions };
});

export default SessionsModule;

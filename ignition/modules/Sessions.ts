import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SessionsModule = buildModule("SessionsModule", (m) => {
  const sessions = m.contract("Sessions", []);

  return { sessions };
});

export default SessionsModule;

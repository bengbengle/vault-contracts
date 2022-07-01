import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from "fs";

type StateVariable = {
  name: string;
  slot: string;
  offset: number;
  type: string;
};

export const getContractStorageLayout = async (
  hre: HardhatRuntimeEnvironment,
  smartContractName: string
) => {
  const { sourceName, contractName } = await hre.artifacts.readArtifact(
    smartContractName
  );

  const stateVariables: StateVariable[] = [];

  for (const artifactPath of await hre.artifacts.getBuildInfoPaths()) {
    const artifact = fs.readFileSync(artifactPath);
    const artifactJsonABI = JSON.parse(artifact.toString());

    const artifactIncludesStorageLayout = artifactJsonABI?.output?.contracts?.[sourceName]?.[contractName]?.storageLayout;

    if (!artifactIncludesStorageLayout) {
      continue;
    }

    const contractStateVariablesFromArtifact = artifactJsonABI.output.contracts[sourceName][contractName].storageLayout.storage;

    for (const stateVariable of contractStateVariablesFromArtifact) {
      stateVariables.push({
        name: stateVariable.label,
        slot: stateVariable.slot,
        offset: stateVariable.offset,
        type: stateVariable.type,
      });
    }

    // 同一个合约可以出现在多个工件中；因此 , 如果我们已经获得了一次存储布局 , 我们就会中断
    break;
  }

  return stateVariables;
};

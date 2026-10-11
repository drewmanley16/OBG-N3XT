import { createHash, randomBytes } from "node:crypto";
import { Barretenberg, UltraHonkBackend } from "@aztec/bb.js";
import { Noir, type CompiledCircuit } from "@noir-lang/noir_js";
import circuit from "./circuit/school_vaccines.json";

// One Barretenberg instance per server process.
const g = globalThis as unknown as { __bb?: Promise<{ noir: Noir; backend: UltraHonkBackend }> };
function load() {
  return (g.__bb ??= (async () => {
    const api = await Barretenberg.new({ threads: 1 });
    return {
      noir: new Noir(circuit as CompiledCircuit),
      backend: new UltraHonkBackend((circuit as CompiledCircuit).bytecode, api),
    };
  })());
}

export const sha256Hex = (bytes: Uint8Array) => createHash("sha256").update(bytes).digest("hex");
export const toHex = (b: Uint8Array) => Buffer.from(b).toString("hex");
export const fromHex = (h: string) => new Uint8Array(Buffer.from(h.replace(/^0x/, ""), "hex"));

/** Proves `doses` meet `minDoses` for this Ledger address, without revealing `doses`. */
export async function prove(doses: number[], minDoses: readonly number[], holder: string) {
  const { noir, backend } = await load();
  const salt = BigInt("0x" + randomBytes(31).toString("hex")).toString();
  const { witness, returnValue } = await noir.execute({ doses, salt, min_doses: [...minDoses], holder });
  const { proof, publicInputs } = await backend.generateProof(witness);
  return { proof: toHex(proof), publicInputs, commitment: String(returnValue), proofHash: sha256Hex(proof) };
}

export async function verify(proofHex: string, publicInputs: string[]) {
  const { backend } = await load();
  try {
    return await backend.verifyProof({ proof: fromHex(proofHex), publicInputs });
  } catch {
    return false;
  }
}

/** Public inputs layout: min_doses[7], holder, commitment (return value). */
export function readPublicInputs(publicInputs: string[]) {
  return {
    minDoses: publicInputs.slice(0, 7).map((x) => Number(BigInt(x))),
    holder: BigInt(publicInputs[7] ?? 0),
    commitment: publicInputs[8],
  };
}

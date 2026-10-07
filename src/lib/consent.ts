import { recoverMessageAddress, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { PREDICATES, type AccessRequest } from "./types";

// The consent is a plain-text message (EIP-191 personal_sign). The Ledger shows
// every line on its screen, so the patient reads exactly what they approve.
// We don't use EIP-712: the Ethereum app only displays typed data readably when
// Ledger has an ERC-7730 descriptor for it, otherwise it demands blind signing.
export function consentText(req: AccessRequest, expiresAt: number) {
  return [
    "OBG Health Vault consent",
    `Verifier: ${req.verifier}`,
    `Share: ${req.plan.fields.join(", ") || "nothing"}`,
    `Prove: ${req.plan.predicates.map((p) => PREDICATES[p]).join("; ") || "nothing"}`,
    `Expires: ${new Date(expiresAt * 1000).toISOString().slice(0, 16).replace("T", " ")} UTC`,
    `Request: ${req.id}`,
  ].join("\n");
}

export function newExpiry(req: AccessRequest, now = Date.now()) {
  return Math.floor(now / 1000) + req.plan.durationMinutes * 60;
}

// Returns the address that signed, or null for a malformed signature.
export async function recoverSigner(message: string, signature: Hex) {
  try {
    return await recoverMessageAddress({ message, signature });
  } catch {
    return null;
  }
}

// Used only when NEXT_PUBLIC_LEDGER_TRANSPORT=simulated (no Docker, no device).
const DEV_KEY = (process.env.DEV_SIGNER_KEY ??
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d") as Hex; // well-known test key, never fund it
export const devAccount = privateKeyToAccount(DEV_KEY);

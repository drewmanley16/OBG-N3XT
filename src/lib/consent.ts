import { verifyTypedData, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import type { AccessRequest } from "./types";

// EIP-712 consent message. On a Ledger, the Ethereum app displays these fields
// in readable form, so the patient sees exactly what they're approving.
export const domain = { name: "OBG Health Vault", version: "1", chainId: 1 } as const;

export const types = {
  Consent: [
    { name: "requestId", type: "string" },
    { name: "verifier", type: "string" },
    { name: "share", type: "string" },
    { name: "prove", type: "string" },
    { name: "expiresAt", type: "uint256" },
  ],
} as const;

export function buildConsent(req: AccessRequest, now = Date.now()) {
  return {
    requestId: req.id,
    verifier: req.verifier,
    share: req.plan.fields.join(", ") || "nothing",
    prove: req.plan.predicates.join(", ") || "nothing",
    expiresAt: BigInt(Math.floor(now / 1000) + req.plan.durationMinutes * 60),
  };
}

export type Consent = ReturnType<typeof buildConsent>;

export async function verifyConsent(address: Hex, message: Consent, signature: Hex) {
  try {
    return await verifyTypedData({ address, domain, types, primaryType: "Consent", message, signature });
  } catch {
    return false; // malformed signature or address
  }
}

// TODO(ledger-dmk): sign in the browser on the patient's Ledger instead:
//   @ledgerhq/device-management-kit + @ledgerhq/device-signer-kit-ethereum
//   signerEth.signTypedData("44'/60'/0'/0/0", { domain, types, primaryType: "Consent", message })
// Until then, a dev key simulates the device so the full flow can be demoed.
const DEV_KEY = (process.env.DEV_SIGNER_KEY ??
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d") as Hex; // well-known test key, never fund it

export async function simulateLedgerSign(message: Consent) {
  const account = privateKeyToAccount(DEV_KEY);
  const signature = await account.signTypedData({ domain, types, primaryType: "Consent", message });
  return { address: account.address, signature };
}

import type { Hex } from "viem";
import type { AccessRequest, AuditEntry, Grant } from "./types";

// In-memory store for the demo. Survives hot reloads via globalThis.
// TODO: persist (and encrypt with Ledger Key Ring) for a real deployment.
type Store = { patientAddress: Hex | null; requests: AccessRequest[]; grants: Grant[]; audit: AuditEntry[] };
const g = globalThis as unknown as { __store?: Store };
export const store = (g.__store ??= { patientAddress: null, requests: [], grants: [], audit: [] });

export function audit(event: AuditEntry["event"], verifier: string, detail: string) {
  store.audit.unshift({ at: new Date().toISOString(), event, verifier, detail });
}

export const simulated = process.env.NEXT_PUBLIC_LEDGER_TRANSPORT === "simulated";

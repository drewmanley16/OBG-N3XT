import type { AccessRequest, AuditEntry, Grant } from "./types";

// In-memory store for the demo. Survives hot reloads via globalThis.
// TODO: persist (and encrypt with Ledger Key Ring) for a real deployment.
const g = globalThis as unknown as {
  __store?: { requests: AccessRequest[]; grants: Grant[]; audit: AuditEntry[] };
};
export const store = (g.__store ??= { requests: [], grants: [], audit: [] });

export function audit(event: AuditEntry["event"], verifier: string, detail: string) {
  store.audit.unshift({ at: new Date().toISOString(), event, verifier, detail });
}

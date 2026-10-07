"use client";
import { useCallback, useEffect, useState } from "react";
import type { AccessRequest, AuditEntry, Grant } from "@/lib/types";

export type State = { requests: AccessRequest[]; grants: Grant[]; audit: AuditEntry[] };

// Poll the demo store so the patient and clinic tabs stay in sync.
export function useStore() {
  const [state, setState] = useState<State>({ requests: [], grants: [], audit: [] });
  const refresh = useCallback(async () => {
    const res = await fetch("/api/state", { cache: "no-store" });
    if (res.ok) setState(await res.json());
  }, []);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    refresh();
    const t = setInterval(refresh, 2000);
    return () => clearInterval(t);
  }, [refresh]);
  return { ...state, refresh };
}

export function useNow(intervalMs = 1000) {
  const [now, setNow] = useState(0); // set on mount so prerender stays static
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setNow(Date.now());
    const t = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(t);
  }, [intervalMs]);
  return now;
}

export function timeLeft(expiresAt: string, now: number) {
  const s = Math.max(0, Math.floor((new Date(expiresAt).getTime() - now) / 1000));
  return s === 0 ? "expired" : `${Math.floor(s / 60)}m ${String(s % 60).padStart(2, "0")}s left`;
}

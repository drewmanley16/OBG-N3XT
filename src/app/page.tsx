"use client";
import Link from "next/link";
import { useState } from "react";
import { timeLeft, useNow, useStore } from "@/components/useStore";
import { PREDICATES, type AccessRequest } from "@/lib/types";

export default function PatientVault() {
  const { requests, grants, audit, refresh } = useStore();
  const now = useNow();
  const pending = requests.filter((r) => r.status === "pending");

  return (
    <main className="mx-auto w-full max-w-4xl px-4 py-8 space-y-8">
      <header className="flex items-center justify-between">
        <div>
          <p className="text-sm text-neutral-500">Patient view</p>
          <h1 className="text-2xl font-semibold">My Health Vault</h1>
        </div>
        <Link href="/clinic" className="text-sm underline">Open clinic view →</Link>
      </header>

      <section className="space-y-3">
        <h2 className="font-medium">Access requests</h2>
        {pending.length === 0 && <p className="text-sm text-neutral-500">No pending requests.</p>}
        {pending.map((r) => <RequestCard key={r.id} request={r} onDone={refresh} />)}
      </section>

      <section className="space-y-3">
        <h2 className="font-medium">Active access</h2>
        {grants.filter((g) => new Date(g.expiresAt).getTime() > now).length === 0 && (
          <p className="text-sm text-neutral-500">Nobody can see your data right now.</p>
        )}
        {grants.filter((g) => new Date(g.expiresAt).getTime() > now).map((g) => (
          <div key={g.id} className="rounded-lg border border-neutral-200 dark:border-neutral-800 p-3 text-sm flex justify-between">
            <span><b>{g.verifier}</b>: {[...g.fields, ...g.predicates].join(", ")}</span>
            <span className="tabular-nums text-neutral-500">{timeLeft(g.expiresAt, now)}</span>
          </div>
        ))}
      </section>

      <section className="space-y-2">
        <h2 className="font-medium">Audit log</h2>
        <ul className="text-sm divide-y divide-neutral-200 dark:divide-neutral-800">
          {audit.map((a, i) => (
            <li key={i} className="py-2 flex gap-3">
              <span className="w-20 shrink-0 tabular-nums text-neutral-500">{new Date(a.at).toLocaleTimeString()}</span>
              <span className="w-28 shrink-0 font-medium">{a.event}</span>
              <span><b>{a.verifier}</b>: {a.detail}</span>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}

function RequestCard({ request: r, onDone }: { request: AccessRequest; onDone: () => void }) {
  const [busy, setBusy] = useState(false);
  const act = async (action: "approve" | "deny") => {
    setBusy(true);
    await fetch(`/api/requests/${r.id}/${action}`, { method: "POST", body: "{}" });
    setBusy(false);
    onDone();
  };
  const notShared = r.requestedFields.filter((f) => !r.plan.fields.includes(f));

  return (
    <div className="rounded-xl border border-neutral-200 dark:border-neutral-800 p-4 space-y-4">
      <div>
        <p className="font-medium">{r.verifier}</p>
        <p className="text-sm text-neutral-500">“{r.purpose}”</p>
      </div>
      <div className="text-sm space-y-1">
        <p>Asked for: {r.requestedFields.join(", ") || "unspecified"}</p>
        <p className="text-emerald-700 dark:text-emerald-400">AI agent: {r.plan.rationale}</p>
        {notShared.length > 0 && <p className="text-neutral-500">Withheld: {notShared.join(", ")}</p>}
      </div>

      {/* Mirrors what the Ledger shows for the EIP-712 consent message */}
      <div className="mx-auto max-w-xs rounded-lg bg-black text-white font-mono text-xs p-4 space-y-1">
        <p className="text-center text-neutral-400 pb-1">Ledger: review consent</p>
        <p>Verifier: {r.verifier}</p>
        <p>Share: {r.plan.fields.join(", ") || "nothing"}</p>
        <p>Prove: {r.plan.predicates.map((p) => PREDICATES[p]).join("; ") || "nothing"}</p>
        <p>For: {r.plan.durationMinutes} min</p>
      </div>

      <div className="flex gap-2 justify-center">
        <button disabled={busy} onClick={() => act("deny")} className="rounded-md border px-4 py-2 text-sm">Reject</button>
        <button disabled={busy} onClick={() => act("approve")} className="rounded-md bg-black text-white dark:bg-white dark:text-black px-4 py-2 text-sm">
          {busy ? "Confirm on Ledger…" : "Approve on Ledger"}
        </button>
      </div>
    </div>
  );
}

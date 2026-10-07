"use client";
import Link from "next/link";
import { useState } from "react";
import { timeLeft, useNow, useStore } from "@/components/useStore";
import { FIELDS, type Field } from "@/lib/types";

const PRESETS = [
  { verifier: "Eugene Family Clinic", purpose: "New patient visit for asthma follow-up", fields: [...FIELDS] },
  { verifier: "Campus Pharmacy", purpose: "Filling an amoxicillin prescription", fields: ["allergies", "medications", "conditions", "dob"] as Field[] },
  { verifier: "McDonald Theatre", purpose: "Concert venue vaccination check", fields: ["name", "dob", "immunizations"] as Field[] },
];

type Redeemed = { data: Record<string, unknown>; proofs: { statement: string; value: boolean }[]; consent: { patientAddress: string; simulated: boolean } };

export default function Clinic() {
  const { requests, grants } = useStore();
  const now = useNow();
  const [form, setForm] = useState(PRESETS[0]);
  const [view, setView] = useState<{ id: string; result?: Redeemed; error?: string } | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    setBusy(true);
    await fetch("/api/requests", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ verifier: form.verifier, purpose: form.purpose, requestedFields: form.fields }),
    });
    setBusy(false);
  };
  const redeem = async (id: string) => {
    const res = await fetch(`/api/grants/${id}`, { cache: "no-store" });
    const body = await res.json();
    setView(res.ok ? { id, result: body } : { id, error: body.error });
  };
  const toggle = (f: Field) =>
    setForm({ ...form, fields: form.fields.includes(f) ? form.fields.filter((x) => x !== f) : [...form.fields, f] });

  return (
    <main className="mx-auto w-full max-w-4xl px-4 py-8 space-y-8">
      <header className="flex items-center justify-between">
        <div>
          <p className="text-sm text-neutral-500">Provider view</p>
          <h1 className="text-2xl font-semibold">Request patient data</h1>
        </div>
        <Link href="/" className="text-sm underline">← Patient view</Link>
      </header>

      <section className="rounded-xl border border-neutral-200 dark:border-neutral-800 p-4 space-y-3">
        <div className="flex flex-wrap gap-2">
          {PRESETS.map((p) => (
            <button key={p.verifier} onClick={() => setForm(p)} className="rounded-full border px-3 py-1 text-xs">{p.verifier}</button>
          ))}
        </div>
        <input className="w-full rounded-md border px-3 py-2 text-sm bg-transparent" value={form.verifier} onChange={(e) => setForm({ ...form, verifier: e.target.value })} placeholder="Who is asking" />
        <input className="w-full rounded-md border px-3 py-2 text-sm bg-transparent" value={form.purpose} onChange={(e) => setForm({ ...form, purpose: e.target.value })} placeholder="Why" />
        <div className="flex flex-wrap gap-3 text-sm">
          {FIELDS.map((f) => (
            <label key={f} className="flex items-center gap-1">
              <input type="checkbox" checked={form.fields.includes(f)} onChange={() => toggle(f)} /> {f}
            </label>
          ))}
        </div>
        <button disabled={busy} onClick={submit} className="rounded-md bg-black text-white dark:bg-white dark:text-black px-4 py-2 text-sm">
          {busy ? "AI agent is reviewing…" : "Send request"}
        </button>
      </section>

      <section className="space-y-2">
        <h2 className="font-medium">Requests</h2>
        {requests.map((r) => {
          const grant = grants.find((g) => g.id === r.grantId);
          return (
            <div key={r.id} className="rounded-lg border border-neutral-200 dark:border-neutral-800 p-3 text-sm flex items-center justify-between gap-2">
              <span><b>{r.verifier}</b>: {r.purpose}</span>
              <span className="flex items-center gap-3 shrink-0">
                <span className="text-neutral-500">{grant ? timeLeft(grant.expiresAt, now) : r.status}</span>
                {grant && <button onClick={() => redeem(grant.id)} className="underline">View</button>}
              </span>
            </div>
          );
        })}
      </section>

      {view && (
        <section className="rounded-xl border border-neutral-200 dark:border-neutral-800 p-4 space-y-3 text-sm">
          <h2 className="font-medium">What you received</h2>
          {view.error && <p className="text-red-600">{view.error}</p>}
          {view.result && (
            <>
              {view.result.proofs.map((p) => (
                <p key={p.statement}>{p.value ? "✅" : "❌"} {p.statement} <span className="text-neutral-500">(proof only, no record shared)</span></p>
              ))}
              {Object.keys(view.result.data).length > 0 && (
                <pre className="overflow-x-auto rounded-md bg-neutral-100 dark:bg-neutral-900 p-3 text-xs">{JSON.stringify(view.result.data, null, 2)}</pre>
              )}
              <p className="text-xs text-neutral-500 break-all">
                Consent signed by {view.result.consent.patientAddress}
                {view.result.consent.simulated && " (simulated Ledger)"}
              </p>
            </>
          )}
        </section>
      )}
    </main>
  );
}

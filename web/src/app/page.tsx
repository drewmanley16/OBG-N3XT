"use client";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { getLedgerAddress, signOnLedger, SPECULOS_URL, usingEmulator } from "@/lib/ledger-client";
import { requestMessage } from "@/lib/messages";
import { OREGON_K12, VACCINES } from "@/lib/requirements";
import { supabase, type ProofRequest, type Student } from "@/lib/supabase";

type Verification = {
  ok: boolean;
  checks: { label: string; ok: boolean }[];
  student: { name: string; ledgerAddress: string };
  requirement: string;
  proofBytes: number;
  proofHash: string;
  commitment: string;
  releaseMessage: string;
};

const short = (a: string) => `${a.slice(0, 6)}…${a.slice(-4)}`;

export default function SchoolPortal() {
  const [school, setSchool] = useState("South Eugene High School");
  const [students, setStudents] = useState<Student[]>([]);
  const [requests, setRequests] = useState<ProofRequest[]>([]);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<string | null>(null);
  const [results, setResults] = useState<Record<string, Verification | { error: string }>>({});
  const [schoolAddress, setSchoolAddress] = useState<string | null>(null);
  const [ledgerStatus, setLedgerStatus] = useState<string | null>(null);

  const verifying = useRef(new Set<string>());

  const load = useCallback(async () => {
    const [s, r] = await Promise.all([
      supabase.from("students").select("*").order("created_at", { ascending: false }),
      supabase.from("proof_requests").select("*").order("created_at", { ascending: false }).limit(50),
    ]);
    if (s.data) setStudents(s.data as Student[]);
    if (!r.data) return;
    const rows = r.data as ProofRequest[];
    setRequests(rows);
    // Verify each newly approved proof once.
    for (const row of rows.filter((x) => x.status === "approved" && !verifying.current.has(x.id))) {
      verifying.current.add(row.id);
      fetch("/api/verify", { method: "POST", body: JSON.stringify({ requestId: row.id }) })
        .then((res) => res.json())
        .then((v) => setResults((x) => ({ ...x, [row.id]: v })));
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    load();
    // Realtime: the moment a student approves on their Ledger, this updates.
    const channel = supabase
      .channel("school-portal")
      .on("postgres_changes", { event: "*", schema: "public", table: "proof_requests" }, () => load())
      .subscribe();
    const poll = setInterval(load, 5000); // new registrations
    return () => {
      supabase.removeChannel(channel);
      clearInterval(poll);
    };
  }, [load]);

  // Pair the school's Ledger and record it in the public school registry.
  const connectLedger = async () => {
    setLedgerStatus("Connecting to the school's Ledger…");
    try {
      const address = await getLedgerAddress();
      const { error } = await supabase.from("schools").upsert({ name: school, ledger_address: address });
      if (error) throw new Error(error.message);
      setSchoolAddress(address);
      setLedgerStatus(null);
      return address;
    } catch (e) {
      setLedgerStatus(`Ledger: ${(e as Error).message}`);
      return null;
    }
  };

  // Every request is signed on the school's Ledger; the student's app checks it.
  const requestProof = async (student: Student) => {
    const address = schoolAddress ?? (await connectLedger());
    if (!address) return;
    const nonce = crypto.getRandomValues(new Uint8Array(16)).reduce((s, b) => s + b.toString(16).padStart(2, "0"), "");
    const message = requestMessage(school, student.name, OREGON_K12.id, nonce);
    try {
      setLedgerStatus(`Review the request on the school's Ledger and hold to sign${usingEmulator ? ` (${SPECULOS_URL.replace("http://", "")})` : ""}`);
      const signature = await signOnLedger(message);
      const { data, error } = await supabase
        .from("proof_requests")
        .insert({ student_id: student.id, school, nonce, school_address: address, request_message: message, request_signature: signature })
        .select()
        .single();
      if (error) throw new Error(error.message);
      setSelected((data as ProofRequest).id);
      setLedgerStatus(null);
      load();
    } catch (e) {
      setLedgerStatus(`Ledger: ${(e as Error).message}`);
    }
  };

  const filtered = students.filter((s) => s.name.toLowerCase().includes(query.toLowerCase()));
  const mine = useMemo(() => requests.filter((r) => r.school === school), [requests, school]);
  const nameOf = (id: string) => students.find((s) => s.id === id)?.name ?? "Student";
  const active = mine.find((r) => r.id === selected) ?? mine[0];

  return (
    <main className="mx-auto w-full max-w-6xl px-4 sm:px-8 py-10 space-y-10">
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="font-mono text-xs tracking-[0.25em] text-accent">SCHOOL PORTAL</p>
          <h1 className="text-4xl sm:text-5xl font-black tracking-tight">Vaccine compliance</h1>
          <p className="mt-2 text-muted max-w-xl">
            Students prove they meet {OREGON_K12.label} requirements with a zero-knowledge proof, released only after they
            approve it on their Ledger. You never see their records.
          </p>
        </div>
        <div className="flex flex-wrap items-end gap-3">
          <label className="block">
            <span className="font-mono text-[10px] tracking-[0.2em] text-faint">REQUESTING AS</span>
            <input
              value={school}
              onChange={(e) => {
                setSchool(e.target.value);
                setSchoolAddress(null);
              }}
              className="mt-1 block w-72 max-w-full rounded-xl bg-raised border border-line px-3 py-2.5 font-semibold outline-none focus:border-accent"
            />
          </label>
          {schoolAddress ? (
            <div className="rounded-xl border border-accent/40 bg-accent/[0.06] px-3 py-2">
              <p className="font-mono text-[10px] tracking-[0.2em] text-accent">SCHOOL LEDGER</p>
              <p className="font-mono text-sm">{short(schoolAddress)}</p>
            </div>
          ) : (
            <button onClick={connectLedger} className="rounded-xl border border-line bg-raised px-4 py-2.5 font-semibold hover:border-accent">
              Connect school Ledger
            </button>
          )}
        </div>
      </header>

      {ledgerStatus && (
        <div
          className={`rounded-2xl border px-5 py-4 flex items-center gap-3 ${ledgerStatus.startsWith("Ledger:") ? "border-danger/40 text-danger" : "border-accent/40 bg-accent/[0.06]"}`}
        >
          {!ledgerStatus.startsWith("Ledger:") && (
            <span className="relative flex h-3 w-3">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-60" />
              <span className="relative inline-flex h-3 w-3 rounded-full bg-accent" />
            </span>
          )}
          <span className="font-semibold">{ledgerStatus}</span>
          {usingEmulator && !ledgerStatus.startsWith("Ledger:") && (
            <a href={SPECULOS_URL} target="_blank" rel="noreferrer" className="ml-auto underline text-muted">
              Open device ↗
            </a>
          )}
        </div>
      )}

      <div className="grid gap-8 lg:grid-cols-[1fr_1.25fr]">
        {/* Registry */}
        <section className="space-y-3">
          <Eyebrow left="Student registry" right={`${students.length} on Supabase`} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search students"
            className="w-full rounded-xl bg-surface border border-line px-4 py-3 outline-none focus:border-accent placeholder:text-faint"
          />
          <div className="rounded-2xl border border-line bg-surface divide-y divide-[var(--line)]">
            {filtered.length === 0 && <p className="p-5 text-muted">No registered students yet. Onboard one in the iPhone app.</p>}
            {filtered.map((s) => (
              <div key={s.id} className="p-4 flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="font-bold truncate">{s.name}</p>
                  <p className="font-mono text-xs text-faint truncate">
                    ledger {short(s.ledger_address)} · proof {s.proof_hash.slice(0, 12)}…
                  </p>
                </div>
                <button
                  onClick={() => requestProof(s)}
                  disabled={!!ledgerStatus && !ledgerStatus.startsWith("Ledger:")}
                  className="shrink-0 rounded-xl bg-accent text-black font-bold px-4 py-2.5 hover:opacity-90 active:scale-[0.98] transition disabled:opacity-40"
                >
                  Request proof
                </button>
              </div>
            ))}
          </div>
        </section>

        {/* Requests + verification */}
        <section className="space-y-3">
          <Eyebrow left="Requests" right={school} />
          {mine.length === 0 && (
            <div className="rounded-2xl border border-line bg-surface p-5 text-muted">Request a proof from a student to start.</div>
          )}
          <div className="flex flex-wrap gap-2">
            {mine.slice(0, 8).map((r) => (
              <button
                key={r.id}
                onClick={() => setSelected(r.id)}
                className={`rounded-full border px-3 py-1.5 text-sm flex items-center gap-2 ${active?.id === r.id ? "border-accent text-text" : "border-line text-muted"}`}
              >
                <Dot status={r.status} />
                {nameOf(r.student_id)}
              </button>
            ))}
          </div>
          {active && <RequestPanel request={active} name={nameOf(active.student_id)} result={results[active.id]} />}
        </section>
      </div>
    </main>
  );
}

function RequestPanel({ request, name, result }: { request: ProofRequest; name: string; result?: Verification | { error: string } }) {
  if (request.status === "pending")
    return (
      <Panel tone="warn">
        <div className="flex items-center gap-3">
          <span className="relative flex h-3 w-3">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-warn opacity-60" />
            <span className="relative inline-flex h-3 w-3 rounded-full bg-warn" />
          </span>
          <p className="text-2xl font-black">Waiting for {name}</p>
        </div>
        <p className="text-muted">They got a notification. Nothing is released until they approve on their Ledger.</p>
        {request.request_signature && <p className="font-mono text-xs text-accent">request signed by school Ledger {short(request.school_address ?? "")}</p>}
        <p className="font-mono text-xs text-faint">request {request.nonce.slice(0, 8)} · sent {new Date(request.created_at).toLocaleTimeString()}</p>
      </Panel>
    );
  if (request.status === "denied")
    return (
      <Panel tone="danger">
        <p className="text-2xl font-black">{name} declined</p>
        <p className="text-muted">No proof was released.</p>
      </Panel>
    );
  if (!result || "error" in result)
    return (
      <Panel tone="neutral">
        <p className="text-muted">{result && result.error !== "verifying" ? result.error : "Verifying proof…"}</p>
      </Panel>
    );

  return (
    <Panel tone={result.ok ? "accent" : "danger"}>
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="font-mono text-xs tracking-[0.2em] text-muted">{result.ok ? "VERIFIED" : "REJECTED"}</p>
          <p className="text-3xl sm:text-4xl font-black tracking-tight">{result.ok ? "Compliant" : "Not verified"}</p>
          <p className="text-muted">
            {name} meets {result.requirement} requirements
          </p>
        </div>
        <div className={`text-5xl ${result.ok ? "text-accent" : "text-danger"}`}>{result.ok ? "✓" : "✕"}</div>
      </div>

      <div className="grid sm:grid-cols-2 gap-3">
        <div className="rounded-xl bg-black/30 border border-line p-4">
          <p className="font-mono text-[10px] tracking-[0.2em] text-accent">YOU LEARNED</p>
          <p className="mt-2 font-semibold">Meets every required dose</p>
          <p className="text-sm text-muted">{VACCINES.map((v, i) => `${v} ${OREGON_K12.minDoses[i]}+`).join(" · ")}</p>
        </div>
        <div className="rounded-xl bg-black/30 border border-line p-4">
          <p className="font-mono text-[10px] tracking-[0.2em] text-faint">YOU DID NOT SEE</p>
          <p className="mt-2 font-semibold">The medical record</p>
          <p className="text-sm text-muted">Dose dates, exact counts, providers, lot numbers, birth date</p>
        </div>
      </div>

      <ul className="space-y-2">
        {result.checks.map((c) => (
          <li key={c.label} className="flex items-center gap-3">
            <span
              className={`grid h-6 w-6 shrink-0 place-items-center rounded-md text-xs font-black ${c.ok ? "bg-accent text-black" : "bg-danger/20 text-danger"}`}
            >
              {c.ok ? "✓" : "✕"}
            </span>
            <span>{c.label}</span>
          </li>
        ))}
      </ul>

      <div className="rounded-xl bg-black border border-line p-4 font-mono text-xs space-y-3 overflow-hidden">
        <p className="text-faint">SIGNED ON LEDGER {short(result.student.ledgerAddress)}</p>
        <pre className="whitespace-pre-wrap text-accent">{result.releaseMessage}</pre>
        <p className="text-faint break-all">
          zk proof {result.proofBytes.toLocaleString()} bytes · sha256 {result.proofHash.slice(0, 24)}… · commitment{" "}
          {result.commitment.slice(0, 18)}…
        </p>
      </div>
    </Panel>
  );
}

function Panel({ tone, children }: { tone: "accent" | "warn" | "danger" | "neutral"; children: React.ReactNode }) {
  const border = { accent: "border-accent/40 bg-accent/[0.06]", warn: "border-warn/40 bg-warn/[0.05]", danger: "border-danger/40 bg-danger/[0.06]", neutral: "border-line bg-surface" }[tone];
  return <div className={`rounded-2xl border p-6 space-y-5 ${border}`}>{children}</div>;
}

function Eyebrow({ left, right }: { left: string; right?: string }) {
  return (
    <div className="flex justify-between font-mono text-[11px] tracking-[0.2em] uppercase px-1">
      <span className="text-muted">{left}</span>
      {right && <span className="text-faint truncate ml-4">{right}</span>}
    </div>
  );
}

function Dot({ status }: { status: ProofRequest["status"] }) {
  const c = { pending: "bg-warn", approved: "bg-accent", denied: "bg-danger" }[status];
  return <span className={`h-2 w-2 rounded-full ${c}`} />;
}

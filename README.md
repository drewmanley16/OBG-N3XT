# OBG-N3XT: Patient-Held Health Vault

Our Oregon team's entry for the **Ledger N3XT hackathon**: a personal health vault where **AI decides the least you need to share, and your Ledger decides whether you share it.**

Based on Drew Manley's paper *A Blueprint for Patient-Held Medical Credentials: Zero-Knowledge Proofs Anchored in Hardware*, written for the Ledger N3XT Research Competition.

## The problem

Most health credentials answer a yes/no question ("vaccinated?", "allergic to penicillin?", "over 18?") by handing over a whole document. The EU Digital COVID Certificate reveals your full name, date of birth and vaccine details on every scan. The Dutch CoronaCheck domestic pass proved the alternative works at national scale: zero-knowledge selective disclosure that showed only initials and birth day and month. But its key lived in a phone app.

## What we're building

The patient's records live in a vault they control. Anyone who wants data (a clinic, pharmacy or venue) has to ask, and nothing leaves without a button press on the patient's Ledger.

There are two ways to share:

1. **Prove a fact, and share no record.** A venue asks "vaccinated?" and gets back only `✅ Has 2+ COVID-19 vaccine doses`. Nothing is handed over, so there's nothing to leak.
2. **Grant temporary access.** A new doctor needs allergies and medications for one visit. The patient approves on the Ledger and the clinic can read just those fields until the grant expires. Every access is logged.

```
clinic ──request──► AI agent ──minimal plan──► patient's Ledger ──signed consent──► time-limited grant
"we need your        "a pharmacy only           "Share: medications                  clinic sees only
 full record"         needs meds + a             Prove: penicillin allergy            what was approved,
                      penicillin yes/no"         For: 15 min   ✓ / ✗"                 then access ends
```

**What "temporary" really means:** a grant controls access through our system. Once someone has *seen* raw data, they could copy it. That's why the agent prefers proving facts over sharing records, and falls back to raw data only when a provider genuinely needs it.

## How we use Ledger

| Ledger tool | Role | Status |
|---|---|---|
| **Signer, via DMK Ethereum Signer Kit + EIP-712** | The consent is an EIP-712 message, so the Ledger shows a readable verifier, the data to share, the facts to prove, and an expiry. The server verifies the signature before creating a grant. | Simulated with a dev key (`src/lib/consent.ts`) |
| **Ring CLI (Ledger Key Ring)** | Encrypts the patient's records at rest with Ledger-backed keys | TODO (`src/lib/vault.ts`) |
| **Agent Stack / Agent Intent** | "Agents propose, humans approve, the Ledger signer enforces." This is exactly our flow. | Framing and pitch |
| **Multisig** *(stretch)* | Emergency break-glass: unlocking records for an unconscious patient needs a proxy's and a doctor's Ledger, and the patient is notified afterward | Idea |

## Run it

```bash
npm install
cp .env.example .env   # optional: add ANTHROPIC_API_KEY; without it the agent uses built-in rules
npm run dev
```

Open http://localhost:3000/clinic in one tab and http://localhost:3000 (the patient view) in another. Send a request from the clinic, approve it as the patient, then click **View** in the clinic tab.

## Code map

| Path | What it does |
|---|---|
| `src/lib/agent.ts` | AI agent (Claude) that turns a request into a minimal disclosure plan, preferring yes/no proofs. It can never exceed what was asked for. |
| `src/lib/consent.ts` | The EIP-712 consent message, signature verification, and a simulated Ledger signer |
| `src/lib/vault.ts` | Loads the record, picks the approved fields, and evaluates yes/no facts |
| `src/lib/store.ts` | In-memory requests, grants and audit log |
| `src/app/api/*` | `POST /requests`, `POST /requests/:id/approve` and `POST /requests/:id/deny`, `GET /grants/:id` (only before expiry), `GET /state` |
| `src/app/page.tsx` | Patient vault: pending requests with a preview of the Ledger screen, active access with countdowns, audit log |
| `src/app/clinic/page.tsx` | Provider view: send requests and view what was granted |
| `data/patient.json` | Fictional sample patient |

## Hackathon scope vs. the paper's vision

Running CL/Idemix or BBS+ proofs *inside* the secure element is a research project, not a one-week build. Today the yes/no facts are evaluated by our server (`evaluate()` in `vault.ts`). The next step is real **BBS selective-disclosure proofs** (W3C Data Integrity BBS Cryptosuite), so verifiers check the issuer's signature instead of trusting us, with the Ledger approving and signing each presentation.

Open problems from the paper to cover in the pitch: revocation without linkability (we use short-lived grants), device loss and re-enrollment, and emergency access.

## TODO

- [ ] **Real Ledger signing:** DMK + Ethereum Signer Kit `signTypedData` in the browser, posting `{ address, signature, expiresAt }` to `/approve`
- [ ] **Ring:** encrypt `data/patient.json` with `wallet-cli ring encrypt` and decrypt on read
- [ ] **BBS proofs** for the yes/no facts
- [ ] Issuer flow: a clinic signs the credential into the vault
- [ ] Persist the store, plus a record upload where Claude parses a lab PDF or vaccine card into fields
- [ ] Emergency break-glass with multisig

## Hackathon checklist

- [ ] Team of 2–4 (Oregon), and send Discord handles to Antoine for mentor access (mentors are unavailable Sat/Sun)
- [ ] Build window: Oct 6–13
- [ ] Demo video and slides (max 2 presenters)
- [ ] **Submit by Oct 13, 2:59 p.m. Pacific** (11:59 p.m. Paris) via the form, with the GitHub link and video
- [ ] Club account posts on X/LinkedIn tagging @Ledger with #LedgerN3XTCollab
- [ ] Finalists announced Oct 15; pitch Oct 16, 3 p.m. Paris

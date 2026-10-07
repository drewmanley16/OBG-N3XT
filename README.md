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
"we need your        "a pharmacy only           "Verifier: Campus Pharmacy           clinic sees only
 full record"         needs meds + a             Share: medications                  what was approved,
                      penicillin yes/no"         Prove: penicillin allergy           then access ends
                                                 Hold to sign"
```

**What "temporary" really means:** a grant controls access through our system. Once someone has *seen* raw data, they could copy it. That's why the agent prefers proving facts over sharing records, and falls back to raw data only when a provider genuinely needs it.

## How we use Ledger

| Ledger tool | Role | Status |
|---|---|---|
| **Signer, via Ledger Device Management Kit (DMK) + Ethereum Signer Kit** | The browser sends the consent text to the patient's Ledger, which shows every line (verifier, data to share, facts to prove, expiry). The patient holds to sign. The server rebuilds the text, recovers the signer, and only creates a grant if it's the vault's paired Ledger. | **Working**, tested on Ledger's emulator |
| **Speculos (Ledger's official emulator)** | Runs the real Ledger Flex firmware and Ethereum app in Docker, so we can build and demo without hardware. The same code talks to a real device over USB (`NEXT_PUBLIC_LEDGER_TRANSPORT=webhid`). | Working |
| **Ring CLI (Ledger Key Ring)** | Would encrypt the records at rest with Ledger-backed keys. Setup (`ring init`) requires a physical device. | Blocked without hardware |
| **Agent Stack / Agent Intent** | "Agents propose, humans approve, the Ledger signer enforces." This is exactly our flow. | Framing and pitch |
| **Multisig** *(stretch)* | Emergency break-glass: unlocking records for an unconscious patient needs a proxy's and a doctor's Ledger | Idea |

**Why plain text and not EIP-712?** The Ledger Ethereum app (1.22) only shows typed data readably when Ledger has an ERC-7730 descriptor for it. Without one, it demands "blind signing", the opposite of what we're pitching. A plain-text `personal_sign` message is shown in full on the device. A registered ERC-7730 descriptor is the production path.

## Run it

Requirements: Node 22+ and Docker.

```bash
npm install
npm run speculos       # starts the Ledger emulator (Flex); device screen at http://localhost:5005
cp .env.example .env   # optional: add ANTHROPIC_API_KEY; without it the agent uses built-in rules
npm run dev
```

1. Open http://localhost:3000/clinic and send a request (try **Campus Pharmacy**).
2. Open http://localhost:3000 (the patient view) and click **Approve on Ledger**.
3. On the device screen (http://localhost:5005), swipe through the consent and **hold to sign**.
4. Back in the clinic tab, click **View**. You'll see only what was approved, until it expires.

No Docker? Set `NEXT_PUBLIC_LEDGER_TRANSPORT=simulated` in `.env` and the server signs with a dev key instead. A real Ledger over USB uses `webhid` (Chrome or Edge).

## Code map

| Path | What it does |
|---|---|
| `src/lib/agent.ts` | AI agent (Claude) that turns a request into a minimal disclosure plan, preferring yes/no proofs. It can never exceed what was asked for. |
| `src/lib/consent.ts` | The consent text the Ledger displays, and signature recovery |
| `src/lib/ledger-client.ts` | Browser side: DMK connects to the emulator or a USB Ledger, then gets the address and signs |
| `scripts/speculos.sh` | Downloads Ledger's Ethereum app and runs the emulator in Docker |
| `src/lib/vault.ts` | Loads the record, picks the approved fields, and evaluates yes/no facts |
| `src/lib/store.ts` | In-memory requests, grants and audit log |
| `src/app/api/*` | `POST /pair`, `POST /requests`, `GET /requests/:id/consent`, `POST /requests/:id/approve` and `POST /requests/:id/deny`, `GET /grants/:id` (only before expiry), `GET /state` |
| `src/app/page.tsx` | Patient vault: pending requests with a preview of the Ledger screen, active access with countdowns, audit log |
| `src/app/clinic/page.tsx` | Provider view: send requests and view what was granted |
| `data/patient.json` | Fictional sample patient |

## Hackathon scope vs. the paper's vision

Running CL/Idemix or BBS+ proofs *inside* the secure element is a research project, not a one-week build. Today the yes/no facts are evaluated by our server (`evaluate()` in `vault.ts`). The next step is real **BBS selective-disclosure proofs** (W3C Data Integrity BBS Cryptosuite), so verifiers check the issuer's signature instead of trusting us, with the Ledger approving and signing each presentation.

Open problems from the paper to cover in the pitch: revocation without linkability (we use short-lived grants), device loss and re-enrollment, and emergency access.

## TODO

- [x] Ledger signing of consent via DMK (emulator; the same code works for a USB device)
- [ ] Make pairing itself a signed message, and persist it
- [ ] **Ring:** encrypt `data/patient.json` with `wallet-cli ring encrypt` (needs a physical device for `ring init`)
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

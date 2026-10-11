# OBG Vault: School Vaccine Proofs, Released by Ledger

Our Oregon team's entry for the **Ledger N3XT hackathon**. Students prove they meet school vaccine requirements with a **zero-knowledge proof**. Schools **never see the medical record**, and **nothing is released without approval on the student's Ledger**.

Based on Drew Manley's paper *A Blueprint for Patient-Held Medical Credentials: Zero-Knowledge Proofs Anchored in Hardware*.

## How it works

```
 ONBOARDING (iPhone)                                   REQUEST → RELEASE
 ┌──────────────────────────────────────────┐          School portal (web)
 │ 1 Connect Ledger                          │            │ signs request on SCHOOL's Ledger
 │ 2 Import records from Epic (simulated)    │            ▼
 │ 3 ZK proof: "meets Oregon K-12" (Noir)    │          Supabase ──Realtime──► iPhone notification
 │ 4 Ledger signs the proof hash             │                                  │ checks school's signature
 └───────────────┬──────────────────────────┘                                  │ student approves on THEIR Ledger
                 ▼                                                              ▼
 Supabase students: name · proof hash · Ledger address · signature     proof + release signature ──► School verifies 8 checks
```

**What the school verifies** (`web/src/app/api/verify`):
1. The ZK proof is valid (UltraHonk, Barretenberg).
2. It proves the Oregon K-12 dose requirements.
3. It's bound to the student's Ledger address (a public input of the circuit).
4. It's the same proof the student registered (its hash matches Supabase).
5. The registration was signed on the student's Ledger.
6. The release to this school was signed on the student's Ledger.
7. The request was signed on the school's Ledger.
8. The release hasn't expired.

**What the school learns:** the student meets every required dose. **What it never sees:** dose dates, exact counts, providers, lot numbers, birth date.

## Pieces

| Path | What |
|---|---|
| `circuits/school_vaccines` | Noir circuit. Private: dose counts and a salt. Public: minimum doses and the holder's Ledger address. Returns a commitment. `nargo test` passes 3 tests. |
| `web/` | Next.js. The **school portal** (`/`), **prover** (`/api/prove`) and **verifier** (`/api/verify`). The school signs requests on its Ledger through Ledger's Device Management Kit. |
| `ios/` | SwiftUI student app: onboarding, Supabase Realtime requests, local notifications, and Ledger signing via raw Ethereum-app commands to the emulator. |
| `supabase/migrations` | `students`, `schools`, `proof_requests`. Realtime is enabled on requests. RLS is wide open for the demo. |
| `scripts/speculos*.sh` | Ledger's official emulator: the student's Ledger on :5005 and the school's on :5006 (different seeds). |

## Run the demo

Requirements: Docker, Node 22+, Xcode 26.

```bash
scripts/speculos.sh && scripts/speculos-school.sh     # two emulated Ledgers
cd web && cp .env.example .env.local                   # add the Supabase anon key
npm install && npm run dev                             # school portal + prover on :3000
cp ios/Config/Secrets.example.xcconfig ios/Config/Secrets.xcconfig   # anon key
open ios/OBGVault.xcodeproj                            # "Trust & Enable" the secp256k1 plugin
```

1. **iPhone app:** Connect Ledger → Connect Epic MyChart → Generate proof → Sign & register. Approve on the student device at http://localhost:5005.
2. **Portal** (http://localhost:3000): Request proof next to the student. Approve on the school device at http://localhost:5006.
3. **iPhone:** a notification arrives. Tap **Approve on Ledger** and sign on :5005.
4. **Portal:** **Compliant**, with all 8 checks.

On the emulator screens, page through with **›** and hold **Hold to sign**. In the app, the **Simulated** Ledger mode needs no Docker.

On a real iPhone, put your Mac's Wi-Fi IP in `MAC_LAN_HOST` in `Secrets.xcconfig`, sign into Xcode with the team account, and run on the device.

## Honest limits

- The Epic import is simulated (sample records).
- The prover runs on our server, so it sees the dose counts. In production, proving would happen on the device or at the provider.
- Each school receives the same proof, so schools that compare notes can link it to one student. Every release is still a separate Ledger approval tied to that school and request, and it expires.
- Realtime plus local notifications stand in for APNs push.
- Supabase row-level security is open for the demo.

## Tests

- **Circuit:** `cd circuits/school_vaccines && nargo test`
- **iOS:** `CryptoTests` covers signature recovery against a real emulator signature, Ledger message chunking, and message strings byte-for-byte identical to the web verifier. `SpeculosTests` and `DemoFlowUITests` drive the emulators and need the stack running.

## Hackathon checklist

- [ ] **Submit by Oct 13, 2:59 p.m. Pacific** (11:59 p.m. Paris) with the GitHub link and demo video
- [ ] Demo video: phone, portal and both Ledger screens
- [ ] Slides (max 2 presenters)
- [ ] Club account posts on X/LinkedIn tagging @Ledger with #LedgerN3XTCollab
- [ ] Finalists announced Oct 15; pitch Oct 16, 3 p.m. Paris

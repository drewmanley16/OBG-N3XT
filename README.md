# ZK-Health: School Vaccine Proofs, Released by Ledger

Students prove they meet school vaccine requirements with a **zero-knowledge proof**. The school **never sees the medical record**, and **nothing is released without approval on the student's Ledger**.

Oregon Blockchain Group's entry for the Ledger N3XT hackathon. Based on Drew Manley's Ledger N3XT research paper, [*A Blueprint for Patient-Held Medical Credentials*](https://www.ledger.com/academy/series/n3xt/research-zero-knowledge-health-credentials-hardware).

## The problem

To enroll a student, schools collect the full immunization record: every date, clinic and lot number, the birth date, and shots they don't need, like flu, HPV and COVID-19. The only question the school needs answered is "does this student meet Oregon K-12 requirements?" But the records are messy (combination shots, early doses, duplicates from other clinics, entries made in error), so families hand over everything and a staff member works it out by hand.

## What it does

1. **Import:** the student pulls their immunization export from Epic into the iPhone app (simulated for the demo).
2. **AI review:** Claude reads the raw export and works out which doses count under Oregon rules. It explains each decision and drafts the minimal disclosure: what the school sees, and what stays on the phone.
3. **Prove:** a Noir zero-knowledge proof shows "meets Oregon K-12". It is bound to the student's Ledger address.
4. **Register:** the student signs the proof hash on their Ledger.
5. **Request and release:** the school requests proof from its portal and signs the request on its own Ledger. The student gets a notification, checks the school's signature, and approves the release on their Ledger.
6. **Verify:** the school runs 8 checks and sees **Compliant**. It never sees dates, counts, providers or the birth date.

## How it works

```
 ONBOARDING (iPhone)                                   REQUEST → RELEASE
 ┌──────────────────────────────────────────┐          School portal (web)
 │ 1 Connect Ledger                          │            │ signs request on SCHOOL's Ledger
 │ 2 Import records from Epic (simulated)    │            ▼
 │ 3 AI review: Claude maps the raw export   │          Supabase ──Realtime──► iPhone notification
 │   to Oregon rules, drafts the disclosure  │                                  │ checks school's signature
 │ 4 ZK proof: "meets Oregon K-12" (Noir)    │                                  │
 │ 5 Ledger signs the proof hash             │                                  │
 └───────────────┬──────────────────────────┘                                  │ student approves on THEIR Ledger
                 ▼                                                              ▼
 Supabase students: name · proof hash · Ledger address · signature     proof + release signature ──► School verifies 8 checks
```

**AI proposes, code checks, ZK proves, Ledger approves.** The agent (`web/src/lib/agent.ts`, Claude Opus 5.5) never holds a key. Its sample export includes:
- combination shots (Pediarix, Kinrix, ProQuad)
- an MMR given before the first birthday
- a duplicate Hep A synced from another clinic
- an entered-in-error Tdap
- flu, COVID-19, HPV and MenACWY shots that schools don't require

Every dose the agent counts is checked in code against the source entry: it must exist, be completed, and cover that vaccine on that date. The circuit then enforces the counts, and only the student's Ledger can approve what gets registered and released.

**Ledger.**
- **Web:** the school portal signs through Ledger's **Device Management Kit** with the **Ethereum signer kit**, using the Speculos transport or WebHID for a real device.
- **iOS:** there is no Swift DMK, so the app sends Ethereum-app APDUs directly.
- **Devices:** two Speculos emulators with different seeds stand in for the student's and the school's Ledger.
- **Messages:** the signed messages are plain ASCII and byte-identical between iOS and the web verifier.

**What the school verifies** (`web/src/app/api/verify`):
1. The ZK proof is valid (UltraHonk, Barretenberg).
2. It proves the Oregon K-12 dose requirements.
3. It is bound to the student's Ledger address, which is a public input of the circuit.
4. It is the same proof the student registered (its hash matches Supabase).
5. The registration was signed on the student's Ledger.
6. The release to this school was signed on the student's Ledger.
7. The request was signed on the school's Ledger.
8. The release hasn't expired.

| Path | What |
|---|---|
| `circuits/school_vaccines` | Noir circuit. Private inputs: dose counts and a salt. Public inputs: minimum doses and the holder's Ledger address. `nargo test` passes. |
| `web/` | Next.js app:<br>• school portal (`/`)<br>• AI review (`/api/agent`)<br>• simulated Epic export (`/api/epic`)<br>• prover (`/api/prove`)<br>• verifier (`/api/verify`)<br>• the school's Ledger via DMK |
| `ios/` | SwiftUI student app:<br>• onboarding with AI review<br>• Supabase Realtime requests and local notifications<br>• Ledger signing |
| `supabase/migrations` | Tables: `students`, `schools`, `proof_requests` |
| `scripts/speculos*.sh` | Emulated Ledgers: the student's on :5005, the school's on :5006 |

## Run it

Requirements: Docker, Node 22+, Xcode 26, and an Anthropic API key.

```bash
scripts/speculos.sh && scripts/speculos-school.sh     # two emulated Ledgers
cd web && cp .env.example .env.local                   # add the Supabase anon key and ANTHROPIC_API_KEY
npm install && npm run dev                             # portal, AI review, prover, verifier on :3000
cp ios/Config/Secrets.example.xcconfig ios/Config/Secrets.xcconfig   # anon key
open ios/OBGVault.xcodeproj                            # "Trust & Enable" the secp256k1 plugin, then run
```

1. **iPhone app:** tap **Connect Ledger**, then **Connect Epic MyChart**, then **Review with AI**, then **Generate proof**, then **Sign & register**. Approve on the student device at http://localhost:5005.
2. **Portal** (http://localhost:3000): click **Request proof** next to the student, and approve on the school device at http://localhost:5006.
3. **iPhone:** when the notification arrives, tap **Approve on Ledger** and sign on :5005.
4. **Portal:** the student shows **Compliant**, with all 8 checks.

On the emulator screens, page through with **›** and hold **Hold to sign**. The app's **Simulated** Ledger mode needs no Docker.

To run on a real iPhone:
- Set `MAC_LAN_HOST` in `Secrets.xcconfig` to the Mac's Wi-Fi IP (`ipconfig getifaddr en0`).
- Keep the phone and the Mac on the same Wi-Fi.
- Keep the repo out of iCloud-synced folders.

**Tests:**
- `cd circuits/school_vaccines && nargo test`
- iOS `CryptoTests`: signature recovery against a real emulator signature, plus message strings byte-identical to the web verifier.
- `SpeculosTests` and `DemoFlowUITests` drive the emulators.

## Honest limits

- The Epic import is simulated with sample records.
- The AI review and the prover run on our server, so the server sees the export and the dose counts. In production, both would run on the device or at the provider.
- Every school receives the same proof, so schools that compare notes could link it to one student. Each release is still a separate Ledger approval, tied to one school and request, and it expires.
- Realtime plus local notifications stand in for APNs push. Supabase row-level security is open for the demo.
- We had no physical Ledger, so the demo runs on the Speculos emulators. The web side also supports a real device over WebHID.

## Next

- **Circuit:** `cd circuits/school_vaccines && nargo test`
- **iOS:** `CryptoTests` covers signature recovery against a real emulator signature, Ledger message chunking, and message strings byte-for-byte identical to the web verifier. `SpeculosTests` and `DemoFlowUITests` drive the emulators and need the stack running.

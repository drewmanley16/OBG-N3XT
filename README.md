# OBG Vault: Prove Your Vaccines, Not Your Record

Our Oregon team's entry for the **Ledger N3XT hackathon**: an iPhone wallet where a patient proves vaccine facts to a provider **without handing over their medical record**, and **nothing is shared without approval on their Ledger**.

Based on Drew Manley's paper *A Blueprint for Patient-Held Medical Credentials: Zero-Knowledge Proofs Anchored in Hardware*, written for the Ledger N3XT Research Competition.

## The flow

```
            request: "prove COVID-19 up to date"
  ┌──────────────────────────────────────────────────────┐
  │                                                      ▼
Provider ◄── proof, limited time ── Ledger ◄── proof ── Patient's credential
  ✗ never reads the record           "Provider: McDonald Theatre        (signed by Lane County
                                      Prove: COVID-19 up to date          Public Health)
                                      Reveal nothing else
                                      Expires: 2026-10-11 22:10 UTC
                                      Proof: 74bcf619..."  Hold to sign
```

1. **Issue.** When the patient pairs their Ledger, a health department signs a vaccine credential bound to the Ledger's address. It contains COVID-19, flu, MMR, Tdap and Hep B status, plus age.
2. **Request.** A provider (venue, university, hospital) asks the patient to prove specific facts, for a set number of minutes.
3. **Prove.** The wallet builds a presentation that reveals only those facts. Name, birth date, dose dates and every other claim stay hidden.
4. **Approve on Ledger.** The device shows the provider, the facts, the expiry and the proof's fingerprint. The patient holds to sign.
5. **Verify.** The provider checks six things with only the issuer's public key: trusted issuer, proof valid against the issuer's signature, signed by the holder's Ledger, that signature covers this exact proof, credential still valid, proof not expired. After expiry, the proof is refused.

## Status

| Piece | Status |
|---|---|
| iPhone app (SwiftUI): Wallet and Provider tabs | ✅ Working |
| Ledger signing via the Ethereum app's personal-sign command | ✅ Working on Ledger's official emulator. Readable on-device text, no blind signing. |
| Holder binding: credential tied to the Ledger address, provider recovers the signer | ✅ Working |
| Selective disclosure (reveal only requested facts) | ✅ Working, using salted hashes signed by the issuer |
| **Zero-knowledge proofs (BBS)** | ⏳ Next. Plugs in behind `ProofEngine`. |
| Real Ledger over Bluetooth (Nano X / Stax / Flex) | ⏳ Same commands (`EthereumAPDU`); needs a BLE transport |
| Provider and patient on separate devices | ⏳ Both live in one app for the demo (`VaultStore`) |

**Why the current proof isn't zero-knowledge yet:** the issuer signs a salted hash of each claim, and the patient opens only the requested ones. Hidden claims really are hidden, but every presentation carries the same hashes, so providers who compare notes could link them. BBS signatures (W3C Data Integrity BBS, the scheme family in the paper) make every proof look fresh. Swap `SaltedHashEngine` for a BBS engine that implements `ProofEngine`; nothing else in the app changes. A TypeScript BBS version is on the local `web-bbs-wip` branch for reference.

## Run it

Requirements: Xcode 26 and Docker (for the Ledger emulator).

```bash
scripts/speculos.sh              # Ledger Flex emulator; device screen at http://localhost:5005
open ios/OBGVault.xcodeproj      # first build: click "Trust & Enable" for the swift-secp256k1 plugin
```

Run the **OBGVault** scheme on an iPhone simulator, then:

1. **Provider** tab: tap **McDonald Theatre**, then **Send request**.
2. **Wallet** tab: tap **Approve on Ledger** (it pairs on first use).
3. On the device screen (http://localhost:5005), page through with **›** and **hold** "Hold to sign". Zoom the browser out if the bottom of the device is cut off.
4. **Provider** tab: open the request and you'll see **Verified**.

No Docker? Switch the Wallet's Ledger mode to **Simulated**, which signs in-app with a test key.

For the demo video, put the simulator next to the emulator's device screen so viewers see the consent land on the Ledger.

## Tests

```bash
cd ios && xcodebuild test -project OBGVault.xcodeproj -scheme OBGVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation
```

- `CryptoTests` covers: recovering the emulator's address from a real Ledger signature, splitting long messages into ≤255-byte Ledger commands, end-to-end verification, rejecting a tampered claim, rejecting an untrusted issuer, rejecting a signature from the wrong key, and keeping the consent ASCII (anything else shows as hex on the Ledger).
- `SpeculosTests` and `DemoFlowUITests` drive the real emulator. They're skipped or fail unless it's running and someone approves on its screen.

## Code map (`ios/OBGVault`)

| Path | What it does |
|---|---|
| `Crypto/ProofEngine.swift` | **The ZK seam.** The `ProofEngine` protocol, the credential and presentation types, and today's `SaltedHashEngine` |
| `Crypto/Verifier.swift` | The consent text shown on the Ledger, and the provider's six checks |
| `Crypto/Ethereum.swift` | Keccak, the personal-sign digest, and recovering a signer's address (secp256k1) |
| `Ledger/LedgerSigner.swift` | Ethereum app commands, the emulator transport over HTTP, and a simulated Ledger |
| `Store/VaultStore.swift` | Pairing, issuing, requests, approval and grants with expiry, plus the audit log |
| `Models/Claims.swift` | Vaccine claims and the sample patient record |
| `Views/` | Wallet and Provider screens |
| `project.yml` | XcodeGen spec that generated the project. Either keep using `xcodegen generate` or just edit in Xcode, but pick one. |

## Hackathon checklist

- [ ] **Submit by Oct 13, 2:59 p.m. Pacific** (11:59 p.m. Paris) via the form, with the GitHub link and demo video
- [ ] Demo video: simulator plus the emulator's device screen
- [ ] Slides (max 2 presenters). Position BBS as "plugging in next" behind `ProofEngine`.
- [ ] Club account posts on X/LinkedIn tagging @Ledger with #LedgerN3XTCollab
- [ ] Finalists announced Oct 15; pitch Oct 16, 3 p.m. Paris

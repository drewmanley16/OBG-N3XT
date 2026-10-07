# OBG-N3XT: Patient-Held Medical Credentials

Our Oregon team's entry for the **Ledger N3XT hackathon**. It is an AI health agent that proves medical facts **without handing over the medical record**, with **Ledger as the trust layer**.

Based on Drew Manley's paper *A Blueprint for Patient-Held Medical Credentials: Zero-Knowledge Proofs Anchored in Hardware*, written for the Ledger N3XT Research Competition.

## The problem

Most health credentials answer a yes/no question ("vaccinated?", "eligible for this prescription?", "allergic to penicillin?") by handing over a full document. The EU Digital COVID Certificate shows your full name, date of birth and vaccine details on every scan. The Dutch CoronaCheck domestic pass showed that the alternative already works at national scale: zero-knowledge selective disclosure with unlinkable proofs, showing only initials and birth day and month. But its key lived in a phone app.

## The idea

1. **Credentials are issued to the patient.** A clinic or public-health authority signs a set of attributes, such as vaccinations, blood type, allergies and prescriptions.
2. **The patient holds the key in hardware.** The credential secret stays on a Ledger device instead of a phone app.
3. **The AI agent minimizes what gets disclosed.** When a verifier (pharmacy, clinic, venue) asks for information, the agent reads the request, works out the smallest fact that answers it (for example "dose count ≥ 2" rather than the full immunization history) and drafts a selective-disclosure proof request.
4. **The patient approves on the Ledger device.** The device shows exactly what will be shared and with whom. Nothing is disclosed without a physical button press.
5. **The verifier checks the proof** against the issuer's public key and learns only the requested fact.

```
issuer ──signs credential──► patient (key on Ledger)
                                   │
verifier ──request──► AI agent ──minimal disclosure──► Ledger approval ──► ZK proof ──► verifier
                     "they only need                   "Share: ≥2 doses
                      dose ≥ 2"                         with CVS? ✓/✗"
```

## How we use Ledger

| Ledger tool | Role in the project |
|---|---|
| **Ledger signer** | The patient approves each disclosure on the device and signs the presentation, which binds the proof to the hardware-held key |
| **Ring CLI** | Encrypts the patient's raw records and credentials at rest with Ledger-backed keys |
| **Ledger Agent Stack** | Exposes the agent's tools (parse records, plan disclosure, request approval) to the AI workflow |

## Hackathon scope vs. the paper's vision

Running CL/Idemix or BBS+ proof generation *inside* the secure element is a research project, not a one-week build. For the hackathon:

- **Selective disclosure:** BBS signatures (W3C Data Integrity BBS Cryptosuite) using an off-the-shelf library on the host
- **Hardware anchoring:** the Ledger key signs and approves each presentation, and Ring CLI encrypts storage
- **AI:** Claude parses uploaded records into attributes and plans the minimal disclosure for each request
- **Demo flows:** pharmacy prescription check, vaccination proof for a venue, and an allergy alert

Open problems the paper flags, which we should address in the pitch: revocation without linkability (we use short-lived credentials), device loss and re-enrollment, and **emergency break-glass access** (a limited dataset with an audit log and notification to the patient).

## Hackathon checklist

- [ ] Team of 2–4 (Oregon), and send Discord handles to Antoine for mentor access (mentors are unavailable Sat/Sun)
- [ ] Build window: Oct 6–13
- [ ] Issuer: mint a BBS-signed demo credential
- [ ] Agent: Claude turns a verifier request into a minimal disclosure
- [ ] Ledger approval and signing of the presentation
- [ ] Verifier page that shows only the disclosed fact
- [ ] Demo video and slides (max 2 presenters)
- [ ] **Submit by Oct 13, 2:59 p.m. Pacific** (11:59 p.m. Paris) via the form, with the GitHub link and video
- [ ] Club account posts on X/LinkedIn tagging @Ledger with #LedgerN3XTCollab
- [ ] Finalists announced Oct 15; pitch Oct 16, 3 p.m. Paris

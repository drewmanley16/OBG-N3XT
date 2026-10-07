# OBG-N3XT: AI Club Treasurer

Our Oregon team's entry for the **Ledger N3XT hackathon**: an AI agent that does useful work, with **Ledger as its trust layer**.

The agent reads club receipts, checks them against the reimbursement policy, and prepares payments. **Nothing gets signed until a human approves it on a Ledger device.**

```
receipt ──► AI extract ──► policy rules ──► payment intent ──► Ledger approval ──► signed
            (Claude)       (deterministic)                     (human on device)
```

## Quick start

```bash
npm install
npm run demo          # runs offline with a mock extractor
cp .env.example .env  # add ANTHROPIC_API_KEY to use Claude for extraction
```

## Layout

| Path | What it does |
|---|---|
| `src/extract.ts` | Reads receipt text into structured data (uses Claude, or the mock) |
| `src/rules.ts` | Applies the club reimbursement policy |
| `src/payment.ts` | Builds a payment intent. It never sends money. |
| `src/ledger.ts` | **Stub.** Gets human approval on the Ledger device. This is where the real integration goes. |
| `samples/` | Policy file and sample receipts |

## Ledger integration options (pick one or more)

- **Ledger signer**: the device shows each payment and a human approves it before signing. This is the core of the demo.
- **Ring CLI**: encrypt stored receipts and payee details with Ledger-backed keys.
- **Ledger Agent Stack**: expose extract, check and pay as agent tools.

## Hackathon checklist

- [ ] Team of 2–4 (Oregon), and send Discord handles to Antoine for mentor access (mentors are unavailable Sat/Sun)
- [ ] Build window: Oct 6–13
- [ ] Real Ledger signing in `src/ledger.ts`
- [ ] UI (web page with receipt upload, review queue and approve button)
- [ ] Demo video
- [ ] Slides (max 2 presenters)
- [ ] **Submit by Oct 13, 2:59 p.m. Pacific** (11:59 p.m. Paris) via the form, with the GitHub link and video
- [ ] Club account posts on X/LinkedIn tagging @Ledger with #LedgerN3XTCollab
- [ ] Finalists announced Oct 15; pitch Oct 16, 3 p.m. Paris

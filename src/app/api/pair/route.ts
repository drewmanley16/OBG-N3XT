import { isAddress } from "viem";
import { devAccount } from "@/lib/consent";
import { audit, simulated, store } from "@/lib/store";

// Links the vault to the patient's Ledger address. Only signatures from this
// address can approve requests. Demo shortcut: first pairing wins.
// TODO: make pairing itself a signed message, and persist it.
export async function POST(req: Request) {
  const { address } = (await req.json().catch(() => ({}))) as { address?: string };
  const next = simulated ? devAccount.address : address;
  if (!next || !isAddress(next)) return Response.json({ error: "Valid address required" }, { status: 400 });
  if (store.patientAddress && store.patientAddress.toLowerCase() !== next.toLowerCase())
    return Response.json({ error: "Vault is already paired with a different Ledger" }, { status: 409 });
  if (!store.patientAddress) audit("paired", "Patient", `Ledger ${next}`);
  store.patientAddress = next;
  return Response.json({ address: next });
}

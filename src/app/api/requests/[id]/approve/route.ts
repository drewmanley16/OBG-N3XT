import { randomUUID } from "node:crypto";
import type { Hex } from "viem";
import { consentText, devAccount, newExpiry, recoverSigner } from "@/lib/consent";
import { audit, simulated, store } from "@/lib/store";

// The patient's Ledger signed the consent text. Rebuild the text from the stored
// request, recover the signer, and only create a grant if it's the paired Ledger.
export async function POST(req: Request, ctx: RouteContext<"/api/requests/[id]/approve">) {
  const { id } = await ctx.params;
  const request = store.requests.find((r) => r.id === id);
  if (!request || request.status !== "pending") return Response.json({ error: "No pending request" }, { status: 404 });

  const body = (await req.json().catch(() => ({}))) as { signature?: Hex; expiresAt?: number };
  let { signature, expiresAt } = body;
  if (simulated) {
    expiresAt = newExpiry(request);
    signature = await devAccount.signMessage({ message: consentText(request, expiresAt) });
    store.patientAddress ??= devAccount.address;
  }
  if (!signature || !expiresAt) return Response.json({ error: "signature and expiresAt required" }, { status: 400 });
  if (expiresAt * 1000 <= Date.now()) return Response.json({ error: "Consent already expired" }, { status: 400 });
  if (!store.patientAddress) return Response.json({ error: "Pair a Ledger first" }, { status: 409 });

  const signer = await recoverSigner(consentText(request, expiresAt), signature);
  if (signer?.toLowerCase() !== store.patientAddress.toLowerCase())
    return Response.json({ error: "Consent not signed by the patient's Ledger" }, { status: 401 });

  const grant = {
    id: randomUUID().slice(0, 8),
    requestId: request.id,
    verifier: request.verifier,
    fields: request.plan.fields,
    predicates: request.plan.predicates,
    expiresAt: new Date(expiresAt * 1000).toISOString(),
    patientAddress: signer,
    signature,
    simulated,
  };
  store.grants.unshift(grant);
  request.status = "approved";
  request.grantId = grant.id;
  audit("approved", request.verifier, `Share [${grant.fields.join(", ") || "nothing"}] prove [${grant.predicates.join(", ") || "nothing"}] until ${grant.expiresAt}`);
  return Response.json(grant);
}

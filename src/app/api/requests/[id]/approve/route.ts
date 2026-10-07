import { randomUUID } from "node:crypto";
import type { Hex } from "viem";
import { buildConsent, simulateLedgerSign, verifyConsent } from "@/lib/consent";
import { audit, store } from "@/lib/store";

// The patient approves a plan. With a real Ledger the browser sends the signature.
// Without one, the dev key simulates the device.
export async function POST(req: Request, ctx: RouteContext<"/api/requests/[id]/approve">) {
  const { id } = await ctx.params;
  const request = store.requests.find((r) => r.id === id);
  if (!request || request.status !== "pending") return Response.json({ error: "No pending request" }, { status: 404 });

  const body = (await req.json().catch(() => ({}))) as { address?: Hex; signature?: Hex; expiresAt?: string };
  let consent = buildConsent(request);
  let signed: { address: Hex; signature: Hex };
  let simulated = false;
  if (body.signature && body.address && body.expiresAt) {
    consent = { ...consent, expiresAt: BigInt(body.expiresAt) };
    signed = { address: body.address, signature: body.signature };
  } else {
    signed = await simulateLedgerSign(consent);
    simulated = true;
  }

  if (!(await verifyConsent(signed.address, consent, signed.signature)))
    return Response.json({ error: "Invalid consent signature" }, { status: 401 });

  const grant = {
    id: randomUUID().slice(0, 8),
    requestId: request.id,
    verifier: request.verifier,
    fields: request.plan.fields,
    predicates: request.plan.predicates,
    expiresAt: new Date(Number(consent.expiresAt) * 1000).toISOString(),
    patientAddress: signed.address,
    signature: signed.signature,
    simulated,
  };
  store.grants.unshift(grant);
  request.status = "approved";
  request.grantId = grant.id;
  audit("approved", request.verifier, `Share [${consent.share}] prove [${consent.prove}] until ${grant.expiresAt}`);
  return Response.json(grant);
}

import { audit, store } from "@/lib/store";
import { evaluate, loadRecord, pick } from "@/lib/vault";

// The verifier redeems a grant. Only approved data, only until it expires.
export async function GET(_req: Request, ctx: RouteContext<"/api/grants/[id]">) {
  const { id } = await ctx.params;
  const grant = store.grants.find((g) => g.id === id);
  if (!grant) return Response.json({ error: "Unknown grant" }, { status: 404 });
  if (new Date(grant.expiresAt).getTime() < Date.now()) {
    audit("expired_access", grant.verifier, `Tried to use expired grant ${grant.id}`);
    return Response.json({ error: "Grant expired" }, { status: 403 });
  }

  const record = await loadRecord();
  audit("accessed", grant.verifier, `Viewed [${grant.fields.join(", ") || "no raw data"}]`);
  return Response.json({
    verifier: grant.verifier,
    expiresAt: grant.expiresAt,
    data: pick(record, grant.fields),
    proofs: evaluate(record, grant.predicates),
    consent: { patientAddress: grant.patientAddress, signature: grant.signature, simulated: grant.simulated },
  });
}

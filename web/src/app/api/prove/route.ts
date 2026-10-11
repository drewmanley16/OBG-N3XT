import { isAddress } from "viem";
import { OREGON_K12, VACCINES } from "@/lib/requirements";
import { prove } from "@/lib/zk";

// Onboarding: the app sends the records it imported (from Epic, faked for the
// demo) and gets back a ZK proof that they meet the school requirements.
export async function POST(req: Request) {
  const { doses, holder } = (await req.json().catch(() => ({}))) as { doses?: number[]; holder?: string };
  if (!holder || !isAddress(holder)) return Response.json({ error: "holder must be a Ledger address" }, { status: 400 });
  if (!Array.isArray(doses) || doses.length !== VACCINES.length || !doses.every((d) => Number.isInteger(d) && d >= 0 && d < 256))
    return Response.json({ error: `doses must be ${VACCINES.length} counts: ${VACCINES.join(", ")}` }, { status: 400 });

  try {
    const result = await prove(doses, OREGON_K12.minDoses, holder.toLowerCase());
    return Response.json({ ...result, requirementSet: OREGON_K12.id });
  } catch (e) {
    const message = (e as Error).message;
    if (message.includes("requirement not met"))
      return Response.json({ error: "These records don't meet the school requirements, so no proof can exist." }, { status: 422 });
    console.error(e);
    return Response.json({ error: "Proof generation failed" }, { status: 500 });
  }
}

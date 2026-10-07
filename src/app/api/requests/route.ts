import { randomUUID } from "node:crypto";
import { planDisclosure } from "@/lib/agent";
import { audit, store } from "@/lib/store";
import { FIELDS, type Field } from "@/lib/types";

// A clinic, pharmacy or venue asks for data. The AI drafts a minimal plan.
export async function POST(req: Request) {
  const body = (await req.json()) as { verifier?: string; purpose?: string; requestedFields?: string[] };
  const verifier = body.verifier?.trim();
  const purpose = body.purpose?.trim();
  if (!verifier || !purpose) return Response.json({ error: "verifier and purpose are required" }, { status: 400 });

  const requestedFields = (body.requestedFields ?? []).filter((f): f is Field => FIELDS.includes(f as Field));
  const request = {
    id: randomUUID().slice(0, 8),
    verifier,
    purpose,
    requestedFields,
    plan: await planDisclosure(verifier, purpose, requestedFields),
    status: "pending" as const,
    createdAt: new Date().toISOString(),
  };
  store.requests.unshift(request);
  audit("requested", verifier, `${purpose} (asked for: ${requestedFields.join(", ") || "unspecified"})`);
  return Response.json(request, { status: 201 });
}

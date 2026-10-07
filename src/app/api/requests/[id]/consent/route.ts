import { consentText, newExpiry } from "@/lib/consent";
import { store } from "@/lib/store";

// The exact text the patient's Ledger will display and sign.
export async function GET(_req: Request, ctx: RouteContext<"/api/requests/[id]/consent">) {
  const { id } = await ctx.params;
  const request = store.requests.find((r) => r.id === id);
  if (!request || request.status !== "pending") return Response.json({ error: "No pending request" }, { status: 404 });
  const expiresAt = newExpiry(request);
  return Response.json({ message: consentText(request, expiresAt), expiresAt });
}

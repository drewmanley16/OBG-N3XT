import { audit, store } from "@/lib/store";

export async function POST(_req: Request, ctx: RouteContext<"/api/requests/[id]/deny">) {
  const { id } = await ctx.params;
  const request = store.requests.find((r) => r.id === id);
  if (!request || request.status !== "pending") return Response.json({ error: "No pending request" }, { status: 404 });
  request.status = "denied";
  audit("denied", request.verifier, request.purpose);
  return Response.json(request);
}

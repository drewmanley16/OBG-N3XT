import { connection } from "next/server";
import { store } from "@/lib/store";

export async function GET() {
  await connection(); // always read live state, never prerender
  return Response.json(store);
}

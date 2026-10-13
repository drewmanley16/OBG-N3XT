import Anthropic from "@anthropic-ai/sdk";
import { AgentError, reviewRecord } from "@/lib/agent";
import type { EpicExport } from "@/lib/epic-export";

export const maxDuration = 120;

// Onboarding: the app sends its raw Epic export and gets back the AI's review:
// counted doses, what was excluded and why, and the disclosure to approve.
export async function POST(req: Request) {
  const record = (await req.json().catch(() => null)) as EpicExport | null;
  if (!record || !Array.isArray(record.entries) || !record.patient?.birthDate)
    return Response.json({ error: "Send the Epic export (FHIR immunization bundle)" }, { status: 400 });

  try {
    return Response.json(await reviewRecord(record));
  } catch (e) {
    if (e instanceof AgentError) return Response.json({ error: e.message }, { status: 422 });
    if (e instanceof Anthropic.AuthenticationError)
      return Response.json({ error: "AI review unavailable: set ANTHROPIC_API_KEY for the web app" }, { status: 503 });
    if (e instanceof Anthropic.RateLimitError)
      return Response.json({ error: "AI review is busy, try again in a moment" }, { status: 429 });
    console.error(e);
    return Response.json({ error: "AI review failed" }, { status: 502 });
  }
}

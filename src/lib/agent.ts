import { FIELDS, PREDICATES, type DisclosurePlan, type Field, type Predicate } from "./types";

// The AI agent proposes the minimal disclosure for a request. It never shares
// anything itself: the patient approves the plan on their Ledger.
export async function planDisclosure(verifier: string, purpose: string, requested: Field[]): Promise<DisclosurePlan> {
  const plan = process.env.ANTHROPIC_API_KEY
    ? await planWithClaude(verifier, purpose, requested).catch((e) => {
        console.error("Claude planning failed, using rules:", e);
        return planWithRules(purpose, requested);
      })
    : planWithRules(purpose, requested);
  return sanitize(plan, requested);
}

async function planWithClaude(verifier: string, purpose: string, requested: Field[]): Promise<DisclosurePlan> {
  const prompt = `You are a patient's privacy agent. A verifier is requesting medical data.
Propose the MINIMUM disclosure that still lets them do their job.
Prefer proving a yes/no predicate over sharing raw data whenever a predicate answers the need.
Only include raw fields from the requested list that are truly necessary for the stated purpose.

Verifier: ${verifier}
Purpose: ${purpose}
Requested fields: ${requested.join(", ") || "(none specified)"}
Available raw fields: ${FIELDS.join(", ")}
Available predicates: ${Object.entries(PREDICATES).map(([k, v]) => `${k} (${v})`).join("; ")}

Reply with JSON only:
{"fields": string[], "predicates": string[], "durationMinutes": number (5-240), "rationale": "one or two sentences shown to the patient"}`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": process.env.ANTHROPIC_API_KEY!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: process.env.ANTHROPIC_MODEL ?? "claude-sonnet-5-5",
      max_tokens: 400,
      messages: [{ role: "user", content: prompt }],
    }),
  });
  if (!res.ok) throw new Error(`Claude API ${res.status}: ${await res.text()}`);
  const data = (await res.json()) as { content: { type: string; text: string }[] };
  const text = data.content.find((c) => c.type === "text")?.text ?? "{}";
  return JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1));
}

// Offline fallback so the demo works without an API key.
function planWithRules(purpose: string, requested: Field[]): DisclosurePlan {
  const p = purpose.toLowerCase();
  if (/vaccin|venue|event|concert|travel/.test(p))
    return { fields: [], predicates: ["covid_vaccinated"], durationMinutes: 5, rationale: "A venue only needs to know you're vaccinated, so we prove it without sharing your immunization history." };
  if (/age|alcohol|21|18/.test(p))
    return { fields: [], predicates: ["over_18"], durationMinutes: 5, rationale: "They only need to know you're an adult. Your birth date stays private." };
  if (/pharm|prescri|refill/.test(p))
    return { fields: ["allergies", "medications"], predicates: [], durationMinutes: 30, rationale: "A pharmacist needs allergies and current medications to check for interactions. Nothing else." };
  if (/visit|appointment|intake|new patient|urgent|clinic/.test(p))
    return { fields: ["allergies", "medications", "conditions"], predicates: [], durationMinutes: 120, rationale: "For a clinical visit, allergies, medications and conditions are relevant. Labs and immunizations aren't needed." };
  return { fields: requested.slice(0, 2), predicates: [], durationMinutes: 15, rationale: "Unclear purpose, so this shares as little as possible for a short time." };
}

// Never let the plan exceed what was asked for, or reference unknown fields.
function sanitize(plan: DisclosurePlan, requested: Field[]): DisclosurePlan {
  const allowed = requested.length ? requested : [...FIELDS];
  return {
    fields: (plan.fields ?? []).filter((f): f is Field => allowed.includes(f as Field)),
    predicates: (plan.predicates ?? []).filter((p): p is Predicate => p in PREDICATES),
    durationMinutes: Math.min(240, Math.max(5, Math.round(plan.durationMinutes || 15))),
    rationale: String(plan.rationale ?? ""),
  };
}

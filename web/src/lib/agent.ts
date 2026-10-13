import Anthropic from "@anthropic-ai/sdk";
import { betaZodOutputFormat } from "@anthropic-ai/sdk/helpers/beta/zod";
import { z } from "zod";
import { CVX_COMPONENTS, type EpicExport } from "@/lib/epic-export";
import { OREGON_K12, VACCINES, type Vaccine } from "@/lib/requirements";

// The AI step of onboarding: Claude reads the raw Epic export, works out which
// doses count toward Oregon's school requirements, and drafts the minimal
// disclosure. Its answer is a proposal: the code below checks every dose
// against the source record, the circuit enforces the counts, and the
// student's Ledger approves what gets registered.

const client = new Anthropic();
const MODEL = "claude-opus-5-5";

const VaccineName = z.enum(VACCINES);

const Review = z.object({
  doses: z.array(z.object({
    sourceId: z.string().describe("id of the export entry this dose comes from"),
    vaccine: VaccineName,
    date: z.string().describe("YYYY-MM-DD, copied from the entry"),
  })).describe("Every valid dose that counts toward a school vaccine. A combination shot appears once per vaccine it covers."),
  excluded: z.array(z.object({
    sourceId: z.string(),
    reason: z.string().describe("One short sentence a student understands"),
  })).describe("Entries, or vaccines within a combination shot, that don't count, and why"),
  vaccines: z.array(z.object({
    vaccine: VaccineName,
    note: z.string().describe("One line: how the requirement is met or what is missing"),
  })),
  disclosure: z.object({
    schoolSees: z.array(z.string()),
    keptPrivate: z.array(z.string()),
  }).describe("The minimal disclosure the student is asked to approve on their Ledger"),
  summary: z.string().describe("Two sentences for the student"),
});
export type Review = z.infer<typeof Review>;

const SYSTEM = `You review a student's immunization export from Epic and decide which doses count toward ${OREGON_K12.label}.

Requirements (minimum valid doses): ${VACCINES.map((v, i) => `${v} ${OREGON_K12.minDoses[i]}`).join(", ")}.

Rules:
- Only entries with status "completed" count. Entered-in-error and not-done entries never count.
- Combination shots count for each vaccine they contain: DTaP-HepB-IPV (Pediarix) = DTaP + Hepatitis B + Polio; DTaP-IPV (Kinrix) = DTaP + Polio; MMRV (ProQuad) = MMR + Varicella.
- The same vaccine on the same date counts once, even if it is listed twice (for example an outside record synced from another clinic).
- MMR, Varicella and Hepatitis A doses given before the first birthday are invalid and don't count. Allow a 4-day grace period.
- The last DTaP and last Polio dose must be on or after the 4th birthday. Tdap must be on or after the 7th birthday.
- Shots schools don't require (flu, COVID-19, HPV, MenACWY) are ignored; list them as excluded with a short reason.
- Copy dates exactly from the export. Never invent a dose.

Disclosure: the school only ever learns that this student meets ${OREGON_K12.id}, proven with a zero-knowledge proof and tied to their Ledger address. Dates, dose counts, clinics, and every non-required shot stay on the phone. Write the disclosure lists from the student's point of view, short and concrete.`;

export class AgentError extends Error {}

export async function reviewRecord(record: EpicExport) {
  const response = await client.beta.messages.parse({
    model: MODEL,
    max_tokens: 16000,
    thinking: { type: "adaptive" },
    output_config: { effort: "medium", format: betaZodOutputFormat(Review) },
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    system: SYSTEM,
    messages: [{ role: "user", content: `Patient export:\n${JSON.stringify(record, null, 2)}` }],
  });
  if (response.stop_reason === "refusal") throw new AgentError("The AI review declined this record.");
  const review = response.parsed_output;
  if (!review) throw new AgentError("The AI review returned no result.");
  return checkReview(review, record);
}

/** Every dose must trace back to a real, completed entry that covers that vaccine on that date. */
export function checkReview(review: Review, record: EpicExport) {
  const entries = new Map(record.entries.map((e) => [e.id, e]));
  const seen = new Set<string>();
  const rejected: string[] = [];
  const doses = review.doses.filter((d) => {
    const entry = entries.get(d.sourceId);
    const ok = entry?.status === "completed" && entry.occurrenceDate === d.date &&
      (CVX_COMPONENTS[entry.vaccineCode.cvx] ?? []).includes(d.vaccine);
    const key = `${d.vaccine}|${d.date}`;
    if (!ok || seen.has(key)) {
      rejected.push(`${d.sourceId} ${d.vaccine}`);
      return false;
    }
    seen.add(key);
    return true;
  });

  const counts = VACCINES.map((v) => doses.filter((d) => d.vaccine === v).length);
  const vaccines = VACCINES.map((v: Vaccine, i) => ({
    vaccine: v,
    validDoses: counts[i],
    required: OREGON_K12.minDoses[i],
    met: counts[i] >= OREGON_K12.minDoses[i],
    note: review.vaccines.find((x) => x.vaccine === v)?.note ?? "",
  }));

  return {
    model: MODEL,
    requirementSet: OREGON_K12.id,
    doses: doses.sort((a, b) => a.date.localeCompare(b.date)),
    doseCounts: counts,
    meetsRequirements: vaccines.every((v) => v.met),
    vaccines,
    excluded: review.excluded,
    rejected, // doses the model proposed that failed the source check
    disclosure: review.disclosure,
    summary: review.summary,
  };
}

import { readFile } from "node:fs/promises";
import { PREDICATES, type Field, type PatientRecord, type Predicate } from "./types";

// TODO(ledger-ring): store the record encrypted with Ledger Key Ring and decrypt on read:
//   wallet-cli ring encrypt -i data/patient.json -o data/patient.json.enc --key health
//   wallet-cli ring decrypt -i data/patient.json.enc --key health
// For the demo scaffold we read the plaintext sample.
export async function loadRecord(): Promise<PatientRecord> {
  return JSON.parse(await readFile(`${process.cwd()}/data/patient.json`, "utf8"));
}

export function pick(record: PatientRecord, fields: Field[]) {
  return Object.fromEntries(fields.map((f) => [f, record[f]]));
}

// TODO(zk): replace with BBS selective-disclosure proofs (W3C Data Integrity BBS)
// so the verifier can check these against the issuer's key instead of trusting us.
export function evaluate(record: PatientRecord, predicates: Predicate[]) {
  const imms = (record.immunizations as { vaccine: string; date: string }[]) ?? [];
  const allergies = (record.allergies as string[]) ?? [];
  const ageYears = (Date.now() - new Date(record.dob as string).getTime()) / (365.25 * 86_400_000);
  const seasonStart = new Date(new Date().getFullYear(), 7, 1); // Aug 1
  const results: Record<Predicate, boolean> = {
    over_18: ageYears >= 18,
    covid_vaccinated: imms.filter((i) => /covid/i.test(i.vaccine)).length >= 2,
    flu_vaccinated_this_season: imms.some((i) => /influenza|flu/i.test(i.vaccine) && new Date(i.date) >= seasonStart),
    penicillin_allergy: allergies.some((a) => /penicillin/i.test(a)),
  };
  return predicates.map((p) => ({ predicate: p, statement: PREDICATES[p], value: results[p] }));
}

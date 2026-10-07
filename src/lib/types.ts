export const FIELDS = [
  "name",
  "dob",
  "blood_type",
  "allergies",
  "medications",
  "conditions",
  "immunizations",
  "lab_results",
] as const;
export type Field = (typeof FIELDS)[number];

// Yes/no facts that can be proven without revealing the underlying record.
export const PREDICATES = {
  over_18: "Patient is 18 or older",
  covid_vaccinated: "Has 2+ COVID-19 vaccine doses",
  flu_vaccinated_this_season: "Has a flu shot this season",
  penicillin_allergy: "Has a penicillin allergy",
} as const;
export type Predicate = keyof typeof PREDICATES;

export type PatientRecord = Record<Field, unknown>;

export interface DisclosurePlan {
  fields: Field[]; // raw data shared temporarily
  predicates: Predicate[]; // yes/no facts proven instead of raw data
  durationMinutes: number;
  rationale: string;
}

export interface AccessRequest {
  id: string;
  verifier: string;
  purpose: string;
  requestedFields: Field[];
  plan: DisclosurePlan;
  status: "pending" | "approved" | "denied";
  createdAt: string;
  grantId?: string;
}

export interface Grant {
  id: string;
  requestId: string;
  verifier: string;
  fields: Field[];
  predicates: Predicate[];
  expiresAt: string;
  patientAddress: string;
  signature: string;
  simulated: boolean;
}

export interface AuditEntry {
  at: string;
  event: "requested" | "approved" | "denied" | "accessed" | "expired_access";
  verifier: string;
  detail: string;
}

// School vaccine requirements. Order must match the circuit's `doses` array.
export const VACCINES = ["DTaP", "Polio", "MMR", "Varicella", "Hepatitis B", "Hepatitis A", "Tdap"] as const;
export type Vaccine = (typeof VACCINES)[number];

export const OREGON_K12 = {
  id: "oregon-k12-2026",
  label: "Oregon K-12 school entry (2026-27)",
  minDoses: [5, 4, 2, 2, 3, 2, 1],
} as const;

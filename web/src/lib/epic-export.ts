import type { Vaccine } from "@/lib/requirements";

// Stand-in for an Epic (MyChart) FHIR immunization export. Real exports are
// messy: combination shots, doses given too early, duplicates synced from
// another clinic, entered-in-error rows, and shots schools don't require.
// The AI agent (lib/agent.ts) turns this into the record the circuit proves.

export type Immunization = {
  id: string;
  status: "completed" | "entered-in-error" | "not-done";
  vaccineCode: { cvx: string; text: string };
  occurrenceDate: string; // YYYY-MM-DD
  location: string;
};

export type EpicExport = {
  resourceType: "Bundle";
  source: string;
  patient: { name: string; birthDate: string };
  entries: Immunization[];
};

/** Which school vaccines each CVX code covers (combination shots cover several). */
export const CVX_COMPONENTS: Record<string, Vaccine[]> = {
  "08": ["Hepatitis B"],
  "110": ["DTaP", "Hepatitis B", "Polio"], // Pediarix
  "20": ["DTaP"],
  "130": ["DTaP", "Polio"], // Kinrix
  "03": ["MMR"],
  "94": ["MMR", "Varicella"], // ProQuad (MMRV)
  "21": ["Varicella"],
  "83": ["Hepatitis A"],
  "115": ["Tdap"],
  "150": [], // influenza
  "208": [], // COVID-19
  "165": [], // HPV
  "114": [], // MenACWY
};

const shot = (id: string, cvx: string, text: string, date: string, location: string, status: Immunization["status"] = "completed"): Immunization =>
  ({ id, status, vaccineCode: { cvx, text }, occurrenceDate: date, location });

const SACRED_HEART = "PeaceHealth Sacred Heart";
const SLOCUM = "Slocum Center Pediatrics";

export const SAMPLE_EXPORT: EpicExport = {
  resourceType: "Bundle",
  source: "Epic · PeaceHealth Sacred Heart",
  patient: { name: "Jordan Rivera", birthDate: "2010-03-01" },
  entries: [
    shot("imm-01", "08", "Hep B, pediatric", "2010-03-01", SACRED_HEART),
    shot("imm-02", "110", "DTaP-HepB-IPV (Pediarix)", "2010-05-02", SLOCUM),
    shot("imm-03", "110", "DTaP-HepB-IPV (Pediarix)", "2010-07-06", SLOCUM),
    shot("imm-04", "110", "DTaP-HepB-IPV (Pediarix)", "2010-09-08", SLOCUM),
    shot("imm-05", "03", "MMR", "2011-02-15", SLOCUM),
    shot("imm-06", "21", "Varicella", "2011-03-15", SLOCUM),
    shot("imm-07", "83", "Hep A, pediatric", "2011-03-15", SLOCUM),
    shot("imm-08", "03", "MMR", "2011-04-05", SLOCUM),
    shot("imm-09", "20", "DTaP", "2011-06-10", SLOCUM),
    shot("imm-10", "83", "Hep A, pediatric", "2011-09-20", SLOCUM),
    shot("imm-11", "83", "HEPATITIS A VACCINE PED/ADOL 2 DOSE", "2011-09-20", "Outside record · Lane County Public Health"),
    shot("imm-12", "130", "DTaP-IPV (Kinrix)", "2014-03-12", SLOCUM),
    shot("imm-13", "94", "MMRV (ProQuad)", "2014-03-12", SLOCUM),
    shot("imm-14", "150", "Influenza, injectable, quadrivalent", "2019-10-14", "Walgreens #10423"),
    shot("imm-15", "115", "Tdap (Boostrix)", "2021-08-24", SLOCUM),
    shot("imm-16", "115", "Tdap (Boostrix)", "2021-08-24", SLOCUM, "entered-in-error"),
    shot("imm-17", "165", "HPV9 (Gardasil 9)", "2021-08-24", SLOCUM),
    shot("imm-18", "114", "MenACWY (Menveo)", "2021-08-24", SLOCUM),
    shot("imm-19", "208", "COVID-19, mRNA (Pfizer)", "2021-11-03", "Oregon Health Authority clinic"),
  ],
};

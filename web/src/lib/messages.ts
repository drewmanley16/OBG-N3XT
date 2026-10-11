// Texts the student's Ledger displays and signs. The iOS app builds the exact
// same strings (Consent.swift). Keep both in sync and plain ASCII.

export const short = (hash: string) => hash.replace(/^0x/, "").slice(0, 32);

export function registrationMessage(name: string, requirementSet: string, proofHash: string) {
  return ["OBG Vault registration", `Student: ${name}`, `Requirements: ${requirementSet}`, `Proof: ${short(proofHash)}`].join("\n");
}

export function releaseMessage(school: string, proofHash: string, nonce: string, expiresAt: Date) {
  const exp = expiresAt.toISOString().slice(0, 16).replace("T", " ");
  return [
    "OBG Vault release",
    `Send proof to: ${school}`,
    `Proof: ${short(proofHash)}`,
    `Request: ${nonce.slice(0, 8)}`,
    `Expires: ${exp} UTC`,
  ].join("\n");
}

/** Signed by the school's Ledger when it asks a student for their proof. */
export function requestMessage(school: string, student: string, requirementSet: string, nonce: string) {
  return ["OBG Vault request", `From: ${school}`, `Student: ${student}`, `Prove: ${requirementSet}`, `Request: ${nonce.slice(0, 8)}`].join("\n");
}

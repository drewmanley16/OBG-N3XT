import { recoverMessageAddress, type Hex } from "viem";
import { registrationMessage, releaseMessage, requestMessage } from "@/lib/messages";
import { OREGON_K12 } from "@/lib/requirements";
import { supabase, type ProofRequest, type Student } from "@/lib/supabase";
import { fromHex, readPublicInputs, sha256Hex, verify } from "@/lib/zk";

// The school verifies a released proof. Everything is checked from public data:
// the proof, the registry row in Supabase, and the two Ledger signatures.
export async function POST(req: Request) {
  const { requestId } = (await req.json().catch(() => ({}))) as { requestId?: string };
  const { data: request } = await supabase.from("proof_requests").select("*").eq("id", requestId ?? "").single<ProofRequest>();
  if (!request) return Response.json({ error: "Unknown request" }, { status: 404 });
  if (request.status !== "approved" || !request.proof || !request.public_inputs || !request.release_signature || !request.expires_at)
    return Response.json({ error: `Request is ${request.status}` }, { status: 409 });
  const { data: student } = await supabase.from("students").select("*").eq("id", request.student_id).single<Student>();
  if (!student) return Response.json({ error: "Unknown student" }, { status: 404 });

  const recover = (message: string, signature: string) =>
    recoverMessageAddress({ message, signature: signature as Hex }).then((a) => a.toLowerCase()).catch(() => null);

  const proofHash = sha256Hex(fromHex(request.proof));
  const inputs = readPublicInputs(request.public_inputs);
  const expiresAt = new Date(request.expires_at);
  const expectedRelease = releaseMessage(request.school, proofHash, request.nonce, expiresAt);
  const [zkValid, regSigner, relSigner, reqSigner] = await Promise.all([
    verify(request.proof, request.public_inputs),
    recover(student.registration_message, student.registration_signature),
    recover(request.release_message ?? "", request.release_signature),
    recover(request.request_message ?? "", request.request_signature ?? ""),
  ]);

  const checks = [
    { label: "Zero-knowledge proof is valid", ok: zkValid },
    { label: `Proves ${OREGON_K12.label} requirements`, ok: inputs.minDoses.join() === OREGON_K12.minDoses.join() },
    { label: "Proof is bound to the student's Ledger", ok: inputs.holder === BigInt(student.ledger_address) },
    { label: "Same proof the student registered (hash matches Supabase)", ok: proofHash === student.proof_hash },
    {
      label: "Registration signed on the student's Ledger",
      ok: regSigner === student.ledger_address &&
        student.registration_message === registrationMessage(student.name, student.requirement_set, student.proof_hash),
    },
    {
      label: `Release to ${request.school} signed on the student's Ledger`,
      ok: relSigner === student.ledger_address && request.release_message === expectedRelease,
    },
    {
      label: `Request signed on ${request.school}'s Ledger`,
      ok: !!request.school_address && reqSigner === request.school_address &&
        request.request_message === requestMessage(request.school, student.name, student.requirement_set, request.nonce),
    },
    { label: "Release not expired", ok: expiresAt.getTime() > Date.now() },
  ];
  return Response.json({
    ok: checks.every((c) => c.ok),
    checks,
    student: { name: student.name, ledgerAddress: student.ledger_address },
    requirement: OREGON_K12.label,
    proofBytes: request.proof.length / 2,
    proofHash,
    commitment: inputs.commitment,
    releaseMessage: request.release_message,
  });
}

import { createClient } from "@supabase/supabase-js";

export const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, {
  auth: { persistSession: false },
});

export type Student = {
  id: string;
  name: string;
  ledger_address: string;
  proof_hash: string;
  requirement_set: string;
  registration_message: string;
  registration_signature: string;
  created_at: string;
};

export type ProofRequest = {
  id: string;
  student_id: string;
  school: string;
  nonce: string;
  status: "pending" | "approved" | "denied";
  created_at: string;
  expires_at: string | null;
  proof: string | null;
  public_inputs: string[] | null;
  release_message: string | null;
  release_signature: string | null;
  school_address: string | null;
  request_message: string | null;
  request_signature: string | null;
};

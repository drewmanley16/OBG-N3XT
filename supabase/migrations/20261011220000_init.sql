-- OBG Vault: students register a proof hash with their Ledger; schools request the proof.

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  ledger_address text not null unique,          -- lowercase 0x address of the student's Ledger
  proof_hash text not null,                     -- sha256 of the Noir proof made at onboarding
  requirement_set text not null,                -- which school rules the proof satisfies
  registration_message text not null,           -- text the Ledger displayed at onboarding
  registration_signature text not null,         -- Ledger personal_sign over registration_message
  created_at timestamptz not null default now()
);

create table if not exists public.proof_requests (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  school text not null,
  nonce text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'denied')),
  created_at timestamptz not null default now(),
  -- Filled in only after the student approves on their Ledger:
  expires_at timestamptz,
  proof text,                                   -- hex Noir proof
  public_inputs jsonb,
  release_message text,                         -- text the Ledger displayed for this release
  release_signature text
);

create index if not exists proof_requests_student_idx on public.proof_requests (student_id, created_at desc);

-- Hackathon demo: the anon key can read and write. Lock this down with auth before real use.
alter table public.students enable row level security;
alter table public.proof_requests enable row level security;
drop policy if exists "demo anon all" on public.students;
drop policy if exists "demo anon all" on public.proof_requests;
create policy "demo anon all" on public.students for all to anon using (true) with check (true);
create policy "demo anon all" on public.proof_requests for all to anon using (true) with check (true);

-- The app listens for new requests; the school page listens for approvals.
alter table public.proof_requests replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.proof_requests;
exception when duplicate_object then null; end $$;

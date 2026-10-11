-- Schools sign each request on their own Ledger; students' apps verify it.

create table if not exists public.schools (
  name text primary key,
  ledger_address text not null,                 -- lowercase 0x address of the school's Ledger
  created_at timestamptz not null default now()
);

alter table public.proof_requests
  add column if not exists school_address text,
  add column if not exists request_message text,  -- text the school's Ledger displayed
  add column if not exists request_signature text;

alter table public.schools enable row level security;
drop policy if exists "demo anon all" on public.schools;
create policy "demo anon all" on public.schools for all to anon using (true) with check (true);

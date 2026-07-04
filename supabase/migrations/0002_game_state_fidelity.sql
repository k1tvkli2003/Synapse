-- Round-trip fidelity for cloud sync: persist the fields the client needs to
-- fully reconstruct Hearts/Streak locally (hearts.max/nextRefillAt,
-- streak.lastActiveDay/freezes), not just the headline counters.
alter table public.synapse_game_state
  add column if not exists hearts_max int not null default 5,
  add column if not exists next_refill_at timestamptz,
  add column if not exists last_active_day text,
  add column if not exists freezes int not null default 0;

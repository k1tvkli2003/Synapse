-- Synapse — initial schema (prompt 05 + 50 + 42)
-- Deployed onto the shared "StudyHUB" Supabase project. Every Synapse table is
-- prefixed `synapse_` so it lives alongside StudyHUB's own tables without any
-- naming collision, and reuses StudyHUB's existing public.touch_updated_at()
-- trigger helper instead of redefining it. Row-level security scopes every
-- row to its owner; public/community content is world-readable but
-- author-writable.

-- ---------- Extensions ----------
create extension if not exists "pgcrypto";

-- ---------- Profiles ----------
create table if not exists public.synapse_profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  handle      text unique not null,
  display_name text not null,
  avatar_url  text,
  role        text not null default 'student',
  specialty   text,
  year        int,
  bio         text,
  prefs       jsonb not null default '{}'::jsonb,
  is_public   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------- Reward economy / gamification ----------
create table if not exists public.synapse_game_state (
  user_id        uuid primary key references public.synapse_profiles(id) on delete cascade,
  xp_total       int not null default 0,
  level          int not null default 1,
  gems           int not null default 0,
  hearts         int not null default 5,
  streak_current int not null default 0,
  streak_best    int not null default 0,
  league         text not null default 'bronze',
  week_xp        int not null default 0,
  updated_at     timestamptz not null default now()
);

-- ---------- Concept mastery (aggregated from every module) ----------
create table if not exists public.synapse_concept_mastery (
  user_id      uuid not null references public.synapse_profiles(id) on delete cascade,
  concept_id   text not null,
  mastery      double precision not null default 0,
  attempts     int not null default 0,
  correct      int not null default 0,
  last_studied timestamptz,
  per_module   jsonb not null default '{}'::jsonb,
  primary key (user_id, concept_id)
);

-- ---------- Spaced-repetition queue (Terms / Cards / Mnemonics) ----------
create table if not exists public.synapse_srs_cards (
  id           text not null,
  owner_id     uuid not null references public.synapse_profiles(id) on delete cascade,
  origin       text not null,
  front        text not null,
  back         text not null,
  concept_id   text,
  interval_days int not null default 0,
  ease         double precision not null default 2.5,
  reps         int not null default 0,
  lapses       int not null default 0,
  due_at       timestamptz,
  updated_at   timestamptz not null default now(),
  primary key (owner_id, id)
);

-- ---------- Quests & achievements ----------
create table if not exists public.synapse_user_quests (
  user_id    uuid not null references public.synapse_profiles(id) on delete cascade,
  quest_id   text not null,
  progress   jsonb not null default '{}'::jsonb,
  claimed_at timestamptz,
  primary key (user_id, quest_id)
);

create table if not exists public.synapse_user_achievements (
  user_id        uuid not null references public.synapse_profiles(id) on delete cascade,
  achievement_id text not null,
  unlocked_at    timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

-- ---------- Inbox / notifications ----------
create table if not exists public.synapse_notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.synapse_profiles(id) on delete cascade,
  title      text not null,
  body       text not null,
  icon_key   text,
  route      text,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

-- ---------- Community content + editorial review (prompt 13 / 41 / 50) ----------
create table if not exists public.synapse_content_items (
  id           uuid primary key default gen_random_uuid(),
  author_id    uuid references public.synapse_profiles(id) on delete set null,
  type         text not null,             -- mnemonic | card | algorithm | case ...
  title        text not null,
  body         text,
  concept_ids  text[] not null default '{}',
  tags         text[] not null default '{}',
  "references" jsonb not null default '[]'::jsonb,
  votes        int not null default 0,
  review_state text not null default 'draft',  -- draft|in_review|approved|needs_update|deprecated
  community    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- A simple report/triage queue for "report an error" (prompt 50 §4).
create table if not exists public.synapse_content_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.synapse_profiles(id) on delete set null,
  subject     text not null,
  detail      text,
  resolved    boolean not null default false,
  created_at  timestamptz not null default now()
);

-- ---------- updated_at trigger ----------
-- Reuses StudyHUB's existing public.touch_updated_at() (identical
-- `new.updated_at = now(); return new;` body) instead of redefining it.
drop trigger if exists trg_synapse_profiles_touch on public.synapse_profiles;
create trigger trg_synapse_profiles_touch before update on public.synapse_profiles
  for each row execute function public.touch_updated_at();

-- ---------- New-user bootstrap: create a profile + game_state ----------
-- Namespaced function/trigger names so they can never collide with any
-- auth.users trigger StudyHUB itself adds later.
create or replace function public.synapse_handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.synapse_profiles (id, handle, display_name)
  values (
    new.id,
    coalesce(split_part(new.email, '@', 1), 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1), 'New User')
  ) on conflict (id) do nothing;
  insert into public.synapse_game_state (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created_synapse on auth.users;
create trigger on_auth_user_created_synapse after insert on auth.users
  for each row execute function public.synapse_handle_new_user();

-- ---------- Row-Level Security ----------
alter table public.synapse_profiles          enable row level security;
alter table public.synapse_game_state        enable row level security;
alter table public.synapse_concept_mastery   enable row level security;
alter table public.synapse_srs_cards         enable row level security;
alter table public.synapse_user_quests       enable row level security;
alter table public.synapse_user_achievements enable row level security;
alter table public.synapse_notifications     enable row level security;
alter table public.synapse_content_items     enable row level security;
alter table public.synapse_content_reports   enable row level security;

-- Profiles: public ones are world-readable; you can edit only your own.
drop policy if exists synapse_profiles_read on public.synapse_profiles;
create policy synapse_profiles_read on public.synapse_profiles for select
  using (is_public or auth.uid() = id);
drop policy if exists synapse_profiles_write on public.synapse_profiles;
create policy synapse_profiles_write on public.synapse_profiles for all
  using (auth.uid() = id) with check (auth.uid() = id);

-- Owner-scoped tables (own rows only).
drop policy if exists synapse_game_state_owner on public.synapse_game_state;
create policy synapse_game_state_owner on public.synapse_game_state for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists synapse_mastery_owner on public.synapse_concept_mastery;
create policy synapse_mastery_owner on public.synapse_concept_mastery for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists synapse_srs_owner on public.synapse_srs_cards;
create policy synapse_srs_owner on public.synapse_srs_cards for all
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists synapse_quests_owner on public.synapse_user_quests;
create policy synapse_quests_owner on public.synapse_user_quests for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists synapse_ach_owner on public.synapse_user_achievements;
create policy synapse_ach_owner on public.synapse_user_achievements for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists synapse_notif_owner on public.synapse_notifications;
create policy synapse_notif_owner on public.synapse_notifications for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Community content: approved items are world-readable; authors manage their own.
drop policy if exists synapse_content_read on public.synapse_content_items;
create policy synapse_content_read on public.synapse_content_items for select
  using (review_state = 'approved' or auth.uid() = author_id);
drop policy if exists synapse_content_write on public.synapse_content_items;
create policy synapse_content_write on public.synapse_content_items for all
  using (auth.uid() = author_id) with check (auth.uid() = author_id);

-- Reports: a user can file and see their own reports.
drop policy if exists synapse_reports_owner on public.synapse_content_reports;
create policy synapse_reports_owner on public.synapse_content_reports for all
  using (auth.uid() = reporter_id) with check (auth.uid() = reporter_id);

-- Leaderboard view (privacy-respecting: public profiles + weekly XP).
create or replace view public.synapse_leaderboard as
  select p.id, p.handle, p.display_name, g.week_xp, g.league, g.level
  from public.synapse_profiles p join public.synapse_game_state g on g.user_id = p.id
  where p.is_public;

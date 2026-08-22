-- Synapse personal-first data plane. This schema is intentionally private:
-- Flutter never receives database credentials and all remote access is routed
-- through the authenticated Go gateway.
begin;

create schema if not exists synapse_private;

revoke all on schema synapse_private from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema synapse_private
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema synapse_private
  revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema synapse_private
  revoke execute on functions from public, anon, authenticated, service_role;

create table if not exists synapse_private.personal_workspaces (
  id text primary key check (id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
  key_version integer not null check (key_version >= 1),
  recovery_generation integer not null check (recovery_generation >= 1),
  recovery_verifier_sha256 char(64) not null check (recovery_verifier_sha256 ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null
);
create unique index if not exists synapse_private_one_workspace
  on synapse_private.personal_workspaces ((true));

create table if not exists synapse_private.trusted_devices (
  id text primary key check (id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
  workspace_id text not null references synapse_private.personal_workspaces(id) on delete cascade,
  label text not null check (char_length(label) between 1 and 80),
  platform text not null check (platform in ('windows', 'android', 'web')),
  role text not null check (role in ('root', 'trusted')),
  signing_public_key text not null,
  encryption_public_key text not null,
  created_at timestamptz not null,
  last_seen_at timestamptz not null,
  revoked_at timestamptz
);
create index if not exists synapse_private_trusted_devices_workspace_idx
  on synapse_private.trusted_devices (workspace_id, created_at);
create unique index if not exists synapse_private_one_active_root
  on synapse_private.trusted_devices (workspace_id)
  where role = 'root' and revoked_at is null;

create table if not exists synapse_private.pairing_sessions (
  id text primary key check (id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
  pairing_code_hash char(64) not null unique check (pairing_code_hash ~ '^[0-9a-f]{64}$'),
  candidate_device_id text not null check (candidate_device_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
  candidate_label text not null check (char_length(candidate_label) between 1 and 80),
  candidate_platform text not null check (candidate_platform in ('windows', 'android', 'web')),
  candidate_signing_public_key text not null,
  candidate_encryption_public_key text not null,
  state text not null check (state in ('pending', 'approved', 'consumed', 'expired')),
  created_at timestamptz not null,
  expires_at timestamptz not null check (expires_at > created_at),
  approved_at timestamptz,
  workspace_id text references synapse_private.personal_workspaces(id) on delete cascade,
  sealed_workspace_key text
);
create index if not exists synapse_private_pairing_expiry_idx
  on synapse_private.pairing_sessions (expires_at)
  where state in ('pending', 'approved');

create table if not exists synapse_private.device_nonces (
  device_id text not null check (device_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
  nonce_hash char(64) not null check (nonce_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  primary key (device_id, nonce_hash)
);
create index if not exists synapse_private_device_nonce_expiry_idx
  on synapse_private.device_nonces (expires_at);

create table if not exists synapse_private.device_access_tokens (
  token_hash char(64) primary key check (token_hash ~ '^[0-9a-f]{64}$'),
  device_id text not null references synapse_private.trusted_devices(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists synapse_private_token_expiry_idx
  on synapse_private.device_access_tokens (expires_at);

create table if not exists synapse_private.encrypted_sync_events (
  server_sequence bigint generated always as identity primary key,
  id text not null unique check (id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
  workspace_id text not null references synapse_private.personal_workspaces(id) on delete restrict,
  device_id text not null references synapse_private.trusted_devices(id) on delete restrict,
  stream text not null check (stream ~ '^[a-z0-9][a-z0-9._-]{0,79}$'),
  entity_hash char(64) not null check (entity_hash ~ '^[0-9a-f]{64}$'),
  kind text not null check (kind in ('attempt', 'reward', 'studyHistory', 'progress', 'mastery', 'note', 'bookmark', 'readingPosition', 'setting', 'deviceReceipt')),
  merge_policy text not null check (merge_policy in ('appendOnly', 'monotonicMaximum', 'lastWriteWins', 'tombstoneWins')),
  logical_revision integer not null check (logical_revision >= 1),
  key_version integer not null check (key_version >= 1),
  idempotency_key text not null check (idempotency_key ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
  client_created_at timestamptz not null,
  nonce text not null,
  cipher_text text not null,
  authentication_tag text not null,
  tombstone boolean not null default false,
  received_at timestamptz not null default now(),
  unique (workspace_id, idempotency_key)
);
create index if not exists synapse_private_sync_pull_idx
  on synapse_private.encrypted_sync_events (workspace_id, server_sequence);

create table if not exists synapse_private.personal_channel_heads (
  workspace_id text not null references synapse_private.personal_workspaces(id) on delete cascade,
  channel text not null check (channel in ('internal', 'beta', 'stable')),
  release_id text not null check (char_length(release_id) between 1 and 160),
  manifest_sha256 char(64) not null check (manifest_sha256 ~ '^[0-9a-f]{64}$'),
  sequence bigint not null check (sequence >= 1),
  updated_at timestamptz not null default now(),
  primary key (workspace_id, channel)
);

create table if not exists synapse_private.signed_chapter_packages (
  id text primary key check (id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'),
  workspace_id text not null references synapse_private.personal_workspaces(id) on delete cascade,
  release_id text not null check (char_length(release_id) between 1 and 160),
  course_source_key text not null check (char_length(course_source_key) between 1 and 160),
  chapter_source_key text not null check (char_length(chapter_source_key) between 1 and 160),
  ordinal integer not null check (ordinal >= 1),
  byte_length bigint not null check (byte_length > 0),
  sha256 char(64) not null check (sha256 ~ '^[0-9a-f]{64}$'),
  signature text not null check (char_length(signature) between 16 and 4096),
  object_key text not null check (char_length(object_key) between 1 and 1024),
  created_at timestamptz not null default now(),
  unique (workspace_id, release_id, chapter_source_key)
);
create index if not exists synapse_private_chapter_packages_release_idx
  on synapse_private.signed_chapter_packages (workspace_id, release_id, ordinal);

-- RLS is intentionally fail-closed. The Go server uses a direct private
-- database connection; there are deliberately no anon/authenticated policies.
alter table synapse_private.personal_workspaces enable row level security;
alter table synapse_private.trusted_devices enable row level security;
alter table synapse_private.pairing_sessions enable row level security;
alter table synapse_private.device_nonces enable row level security;
alter table synapse_private.device_access_tokens enable row level security;
alter table synapse_private.encrypted_sync_events enable row level security;
alter table synapse_private.personal_channel_heads enable row level security;
alter table synapse_private.signed_chapter_packages enable row level security;

revoke all on all tables in schema synapse_private from public, anon, authenticated, service_role;
revoke all on all sequences in schema synapse_private from public, anon, authenticated, service_role;

-- Packages are served only through Go after device-token authorization.
insert into storage.buckets (id, name, public, file_size_limit)
values ('synapse-personal-content', 'synapse-personal-content', false, 67108864)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit;

commit;

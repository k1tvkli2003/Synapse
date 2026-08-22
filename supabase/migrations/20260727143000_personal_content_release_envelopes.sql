-- Expand the private chapter-package contract with the complete public
-- Ed25519 envelope required by Flutter's pinned curriculum trust verifier.
-- Existing pre-envelope rows remain readable as schema-v1 metadata; only rows
-- with every new field populated are eligible to become schema-v2 transport.

alter table synapse_private.signed_chapter_packages
  add column if not exists signing_key_id text,
  add column if not exists source_id text,
  add column if not exists release_channel text,
  add column if not exists canonical_sha256 char(64),
  add column if not exists canonical_byte_length bigint,
  add column if not exists transport_sha256 char(64),
  add column if not exists transport_byte_length bigint,
  add column if not exists signed_at timestamptz;

alter table synapse_private.signed_chapter_packages
  add constraint signed_chapter_packages_release_envelope_complete
  check (
    (
      signing_key_id is null
      and source_id is null
      and release_channel is null
      and canonical_sha256 is null
      and canonical_byte_length is null
      and transport_sha256 is null
      and transport_byte_length is null
      and signed_at is null
    )
    or
    (
      signing_key_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'
      and source_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$'
      and release_channel = 'internal'
      and canonical_sha256 ~ '^[0-9a-f]{64}$'
      and canonical_byte_length > 0
      and transport_sha256 ~ '^[0-9a-f]{64}$'
      and transport_byte_length > 0
      and transport_sha256 = sha256
      and transport_byte_length = byte_length
      and signed_at is not null
    )
  );

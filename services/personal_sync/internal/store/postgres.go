package store

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"synapse.local/personal-sync/internal/domain"
)

// Postgres keeps only encrypted learner events and pairing metadata. It uses
// the non-exposed synapse_private schema; Flutter never talks to this store.
type Postgres struct {
	pool *pgxpool.Pool
}

func OpenPostgres(ctx context.Context, databaseURL string) (*Postgres, error) {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse database URL: %w", err)
	}
	cfg.MaxConns = 4
	cfg.MinConns = 0
	cfg.MaxConnIdleTime = 5 * time.Minute
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("open database pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}
	return &Postgres{pool: pool}, nil
}

func (p *Postgres) Close() {
	p.pool.Close()
}

func (p *Postgres) Bootstrap(ctx context.Context, input domain.BootstrapInput) (domain.PersonalWorkspace, domain.TrustedDevice, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	_, err = tx.Exec(ctx, `
		insert into synapse_private.personal_workspaces
		  (id, key_version, recovery_generation, recovery_verifier_sha256, created_at)
		values ($1, $2, $3, $4, $5)`,
		input.Workspace.ID,
		input.Workspace.KeyVersion,
		input.Workspace.RecoveryGeneration,
		input.RecoveryVerifierSHA256,
		input.Workspace.CreatedAt,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return domain.PersonalWorkspace{}, domain.TrustedDevice{}, ErrAlreadyBootstrap
		}
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	if err := insertDevice(ctx, tx, input.Device); err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	return input.Workspace, input.Device, nil
}

func (p *Postgres) CreatePairing(ctx context.Context, session domain.PairingSession) (domain.PairingSession, error) {
	codeHash := hashPairingCode(session.PairingCode)
	_, err := p.pool.Exec(ctx, `
		insert into synapse_private.pairing_sessions
		  (id, pairing_code_hash, candidate_device_id, candidate_label,
		   candidate_platform, candidate_signing_public_key,
		   candidate_encryption_public_key, state, created_at, expires_at)
		values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		session.ID,
		codeHash,
		session.CandidateDeviceID,
		session.CandidateLabel,
		session.CandidatePlatform,
		session.CandidateSigningPublicKey,
		session.CandidateEncryptionPublicKey,
		session.State,
		session.CreatedAt,
		session.ExpiresAt,
	)
	if err != nil {
		return domain.PairingSession{}, databaseError(err)
	}
	return session, nil
}

func (p *Postgres) ApprovePairing(ctx context.Context, workspaceID, sessionID, pairingCode, candidateEncryptionPublicKey, sealedKey string) (domain.PairingSession, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return domain.PairingSession{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	session, codeHash, err := pairingByID(ctx, tx, sessionID, true)
	if err != nil {
		return domain.PairingSession{}, databaseError(err)
	}
	now := time.Now().UTC()
	if !now.Before(session.ExpiresAt) {
		if _, updateErr := tx.Exec(ctx, `update synapse_private.pairing_sessions set state = 'expired' where id = $1`, sessionID); updateErr != nil {
			return domain.PairingSession{}, databaseError(updateErr)
		}
		if commitErr := tx.Commit(ctx); commitErr != nil {
			return domain.PairingSession{}, databaseError(commitErr)
		}
		return domain.PairingSession{}, ErrExpired
	}
	if session.State != "pending" {
		return domain.PairingSession{}, ErrConflict
	}
	if subtle.ConstantTimeCompare([]byte(codeHash), []byte(hashPairingCode(pairingCode))) != 1 || subtle.ConstantTimeCompare([]byte(session.CandidateEncryptionPublicKey), []byte(candidateEncryptionPublicKey)) != 1 {
		return domain.PairingSession{}, ErrForbidden
	}
	var exists bool
	if err := tx.QueryRow(ctx, `select exists(select 1 from synapse_private.personal_workspaces where id = $1)`, workspaceID).Scan(&exists); err != nil {
		return domain.PairingSession{}, databaseError(err)
	}
	if !exists {
		return domain.PairingSession{}, ErrForbidden
	}
	row := tx.QueryRow(ctx, `
		update synapse_private.pairing_sessions
		set state = 'approved', workspace_id = $2, approved_at = $3, sealed_workspace_key = $4
		where id = $1
		returning id, pairing_code_hash, workspace_id, candidate_device_id, candidate_label,
		  candidate_platform, candidate_signing_public_key, candidate_encryption_public_key,
		  state, created_at, expires_at, approved_at, sealed_workspace_key`,
		sessionID, workspaceID, now, sealedKey,
	)
	approved, _, err := scanPairing(row)
	if err != nil {
		return domain.PairingSession{}, databaseError(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.PairingSession{}, databaseError(err)
	}
	return approved, nil
}

func (p *Postgres) PairingCandidate(ctx context.Context, deviceID, sessionID, pairingCode string) (domain.TrustedDevice, domain.PersonalWorkspace, error) {
	session, codeHash, err := pairingByID(ctx, p.pool, sessionID, false)
	if err != nil {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, databaseError(err)
	}
	if session.CandidateDeviceID != deviceID {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrNotFound
	}
	if !time.Now().UTC().Before(session.ExpiresAt) {
		_, _ = p.pool.Exec(ctx, `update synapse_private.pairing_sessions set state = 'expired' where id = $1 and state in ('pending', 'approved')`, sessionID)
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrExpired
	}
	if session.State != "approved" || session.WorkspaceID == "" || session.SealedWorkspaceKey == nil {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrForbidden
	}
	if subtle.ConstantTimeCompare([]byte(codeHash), []byte(hashPairingCode(pairingCode))) != 1 {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrForbidden
	}
	workspace, err := workspaceByID(ctx, p.pool, session.WorkspaceID)
	if err != nil {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, databaseError(err)
	}
	return domain.TrustedDevice{
		ID:                  session.CandidateDeviceID,
		WorkspaceID:         session.WorkspaceID,
		Label:               session.CandidateLabel,
		Platform:            session.CandidatePlatform,
		Role:                "trusted",
		SigningPublicKey:    session.CandidateSigningPublicKey,
		EncryptionPublicKey: session.CandidateEncryptionPublicKey,
	}, workspace, nil
}

func (p *Postgres) ConsumePairing(ctx context.Context, deviceID, sessionID, pairingCode string) (domain.PairingSession, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return domain.PairingSession{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	session, codeHash, err := pairingByID(ctx, tx, sessionID, true)
	if err != nil {
		return domain.PairingSession{}, databaseError(err)
	}
	if session.CandidateDeviceID != deviceID {
		return domain.PairingSession{}, ErrNotFound
	}
	now := time.Now().UTC()
	if !now.Before(session.ExpiresAt) {
		if _, updateErr := tx.Exec(ctx, `update synapse_private.pairing_sessions set state = 'expired' where id = $1`, sessionID); updateErr != nil {
			return domain.PairingSession{}, databaseError(updateErr)
		}
		if commitErr := tx.Commit(ctx); commitErr != nil {
			return domain.PairingSession{}, databaseError(commitErr)
		}
		return domain.PairingSession{}, ErrExpired
	}
	if session.State != "approved" || session.WorkspaceID == "" || session.SealedWorkspaceKey == nil {
		return domain.PairingSession{}, ErrForbidden
	}
	if subtle.ConstantTimeCompare([]byte(codeHash), []byte(hashPairingCode(pairingCode))) != 1 {
		return domain.PairingSession{}, ErrForbidden
	}
	device := domain.TrustedDevice{
		ID:                  session.CandidateDeviceID,
		WorkspaceID:         session.WorkspaceID,
		Label:               session.CandidateLabel,
		Platform:            session.CandidatePlatform,
		Role:                "trusted",
		SigningPublicKey:    session.CandidateSigningPublicKey,
		EncryptionPublicKey: session.CandidateEncryptionPublicKey,
		CreatedAt:           now,
		LastSeenAt:          now,
	}
	if err := insertDevice(ctx, tx, device); err != nil {
		return domain.PairingSession{}, databaseError(err)
	}
	if _, err := tx.Exec(ctx, `update synapse_private.pairing_sessions set state = 'consumed' where id = $1`, sessionID); err != nil {
		return domain.PairingSession{}, databaseError(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.PairingSession{}, databaseError(err)
	}
	return session, nil
}

func (p *Postgres) Device(ctx context.Context, deviceID string) (domain.TrustedDevice, domain.PersonalWorkspace, error) {
	auth, err := authByDevice(ctx, p.pool, deviceID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrForbidden
	}
	if err != nil {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, databaseError(err)
	}
	return auth.Device, auth.Workspace, nil
}

func (p *Postgres) ConsumeNonce(ctx context.Context, deviceID, nonceHash string, expiresAt time.Time) error {
	_, _ = p.pool.Exec(ctx, `delete from synapse_private.device_nonces where expires_at <= now()`)
	_, err := p.pool.Exec(ctx, `
		insert into synapse_private.device_nonces (device_id, nonce_hash, expires_at)
		values ($1, $2, $3)`, deviceID, nonceHash, expiresAt)
	if isUniqueViolation(err) {
		return ErrReplay
	}
	return databaseError(err)
}

func (p *Postgres) SaveAccessToken(ctx context.Context, token domain.AccessToken) error {
	_, err := p.pool.Exec(ctx, `
		insert into synapse_private.device_access_tokens (token_hash, device_id, expires_at)
		values ($1, $2, $3)`, token.Hash, token.DeviceID, token.ExpiresAt)
	return databaseError(err)
}

func (p *Postgres) AuthenticateToken(ctx context.Context, tokenHash string, now time.Time) (domain.AuthContext, error) {
	row := p.pool.QueryRow(ctx, `
		select w.id, w.key_version, w.recovery_generation, w.created_at,
		       d.id, d.workspace_id, d.label, d.platform, d.role,
		       d.signing_public_key, d.encryption_public_key, d.created_at,
		       d.last_seen_at, d.revoked_at
		from synapse_private.device_access_tokens t
		join synapse_private.trusted_devices d on d.id = t.device_id
		join synapse_private.personal_workspaces w on w.id = d.workspace_id
		where t.token_hash = $1 and t.expires_at > $2 and d.revoked_at is null`, tokenHash, now)
	auth, err := scanAuth(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.AuthContext{}, ErrForbidden
	}
	if err != nil {
		return domain.AuthContext{}, databaseError(err)
	}
	if _, err := p.pool.Exec(ctx, `update synapse_private.trusted_devices set last_seen_at = $2 where id = $1 and revoked_at is null`, auth.Device.ID, now); err != nil {
		return domain.AuthContext{}, databaseError(err)
	}
	auth.Device.LastSeenAt = now
	return auth, nil
}

func (p *Postgres) ListDevices(ctx context.Context, workspaceID string) ([]domain.TrustedDevice, error) {
	rows, err := p.pool.Query(ctx, `
		select id, workspace_id, label, platform, role, signing_public_key,
		       encryption_public_key, created_at, last_seen_at, revoked_at
		from synapse_private.trusted_devices
		where workspace_id = $1
		order by created_at asc`, workspaceID)
	if err != nil {
		return nil, databaseError(err)
	}
	defer rows.Close()
	devices := make([]domain.TrustedDevice, 0)
	for rows.Next() {
		device, scanErr := scanDevice(rows)
		if scanErr != nil {
			return nil, databaseError(scanErr)
		}
		devices = append(devices, device)
	}
	if err := rows.Err(); err != nil {
		return nil, databaseError(err)
	}
	return devices, nil
}

func (p *Postgres) RevokeDevice(ctx context.Context, workspaceID, deviceID string, now time.Time) error {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var role string
	err = tx.QueryRow(ctx, `
		select role from synapse_private.trusted_devices
		where id = $1 and workspace_id = $2
		for update`, deviceID, workspaceID).Scan(&role)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return databaseError(err)
	}
	if role == "root" {
		return ErrForbidden
	}
	if _, err := tx.Exec(ctx, `update synapse_private.trusted_devices set revoked_at = coalesce(revoked_at, $3) where id = $1 and workspace_id = $2`, deviceID, workspaceID, now); err != nil {
		return databaseError(err)
	}
	if _, err := tx.Exec(ctx, `delete from synapse_private.device_access_tokens where device_id = $1`, deviceID); err != nil {
		return databaseError(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return databaseError(err)
	}
	return nil
}

func (p *Postgres) PushEvents(ctx context.Context, auth domain.AuthContext, events []domain.EncryptedSyncEvent) ([]domain.EncryptedSyncEvent, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	result := make([]domain.EncryptedSyncEvent, 0, len(events))
	for _, event := range events {
		stored, insertErr := insertOrReadEvent(ctx, tx, event)
		if insertErr != nil {
			return nil, databaseError(insertErr)
		}
		result = append(result, stored)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, databaseError(err)
	}
	return result, nil
}

func (p *Postgres) PullEvents(ctx context.Context, workspaceID string, after int64, limit int) ([]domain.EncryptedSyncEvent, int64, error) {
	rows, err := p.pool.Query(ctx, `
		select server_sequence, id, workspace_id, device_id, stream, entity_hash,
		       kind, merge_policy, logical_revision, key_version, idempotency_key,
		       client_created_at, nonce, cipher_text, authentication_tag, tombstone,
		       received_at
		from synapse_private.encrypted_sync_events
		where workspace_id = $1 and server_sequence > $2
		order by server_sequence asc
		limit $3`, workspaceID, after, limit)
	if err != nil {
		return nil, after, databaseError(err)
	}
	defer rows.Close()
	result := make([]domain.EncryptedSyncEvent, 0, limit)
	next := after
	for rows.Next() {
		event, scanErr := scanEvent(rows)
		if scanErr != nil {
			return nil, after, databaseError(scanErr)
		}
		next = *event.ServerSequence
		result = append(result, event)
	}
	if err := rows.Err(); err != nil {
		return nil, after, databaseError(err)
	}
	return result, next, nil
}

func (p *Postgres) ContentManifest(ctx context.Context, workspaceID string) (*domain.ContentManifest, error) {
	var head domain.PersonalChannelHead
	err := p.pool.QueryRow(ctx, `
		select channel, release_id, manifest_sha256, sequence, updated_at
		from synapse_private.personal_channel_heads
		where workspace_id = $1 and channel = 'internal'`, workspaceID).Scan(
		&head.Channel, &head.ReleaseID, &head.ManifestSHA256, &head.Sequence, &head.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, databaseError(err)
	}
	rows, err := p.pool.Query(ctx, `
		select id, release_id, course_source_key, chapter_source_key, ordinal,
		       byte_length, sha256, signature, object_key,
		       signing_key_id, source_id, release_channel,
		       canonical_sha256, canonical_byte_length,
		       transport_sha256, transport_byte_length, signed_at
		from synapse_private.signed_chapter_packages
		where workspace_id = $1 and release_id = $2
		order by ordinal asc`, workspaceID, head.ReleaseID)
	if err != nil {
		return nil, databaseError(err)
	}
	defer rows.Close()
	packages := make([]domain.SignedChapterPackage, 0)
	for rows.Next() {
		pkg, scanErr := scanPackage(rows)
		if scanErr != nil {
			return nil, databaseError(scanErr)
		}
		packages = append(packages, pkg)
	}
	if err := rows.Err(); err != nil {
		return nil, databaseError(err)
	}
	return &domain.ContentManifest{SchemaVersion: 1, Head: head, Packages: packages}, nil
}

func (p *Postgres) ContentPackage(ctx context.Context, workspaceID, packageID string) (domain.SignedChapterPackage, error) {
	row := p.pool.QueryRow(ctx, `
		select id, release_id, course_source_key, chapter_source_key, ordinal,
		       byte_length, sha256, signature, object_key,
		       signing_key_id, source_id, release_channel,
		       canonical_sha256, canonical_byte_length,
		       transport_sha256, transport_byte_length, signed_at
		from synapse_private.signed_chapter_packages
		where workspace_id = $1 and id = $2`, workspaceID, packageID)
	pkg, err := scanPackage(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.SignedChapterPackage{}, ErrNotFound
	}
	if err != nil {
		return domain.SignedChapterPackage{}, databaseError(err)
	}
	return pkg, nil
}

func (p *Postgres) RotateRecovery(ctx context.Context, input domain.RecoveryInput, now time.Time) (domain.PersonalWorkspace, domain.TrustedDevice, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var workspace domain.PersonalWorkspace
	var recoveryHash string
	err = tx.QueryRow(ctx, `
		select id, key_version, recovery_generation, recovery_verifier_sha256, created_at
		from synapse_private.personal_workspaces
		where id = $1
		for update`, input.WorkspaceID).Scan(
		&workspace.ID,
		&workspace.KeyVersion,
		&workspace.RecoveryGeneration,
		&recoveryHash,
		&workspace.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, ErrNotFound
	}
	if err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	if workspace.RecoveryGeneration != input.ExpectedGeneration {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, ErrConflict
	}
	if subtle.ConstantTimeCompare([]byte(recoveryHash), []byte(input.RecoveryVerifierSHA256)) != 1 {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, ErrForbidden
	}
	if _, err := tx.Exec(ctx, `update synapse_private.trusted_devices set revoked_at = $2 where workspace_id = $1 and revoked_at is null`, input.WorkspaceID, now); err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	if _, err := tx.Exec(ctx, `
		delete from synapse_private.device_access_tokens
		where device_id in (select id from synapse_private.trusted_devices where workspace_id = $1)`, input.WorkspaceID); err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	if _, err := tx.Exec(ctx, `
		update synapse_private.pairing_sessions
		set state = 'expired'
		where workspace_id = $1 and state in ('pending', 'approved')`, input.WorkspaceID); err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	row := tx.QueryRow(ctx, `
		update synapse_private.personal_workspaces
		set key_version = key_version + 1,
		    recovery_generation = recovery_generation + 1,
		    recovery_verifier_sha256 = $2
		where id = $1
		returning id, key_version, recovery_generation, created_at`, input.WorkspaceID, input.NewRecoveryVerifierHash)
	if err := row.Scan(&workspace.ID, &workspace.KeyVersion, &workspace.RecoveryGeneration, &workspace.CreatedAt); err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	root := input.NewRootDevice
	root.WorkspaceID = workspace.ID
	root.Role = "root"
	root.CreatedAt = now
	root.LastSeenAt = now
	root.RevokedAt = nil
	if err := insertDevice(ctx, tx, root); err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, databaseError(err)
	}
	return workspace, root, nil
}

type queryer interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}

func workspaceByID(ctx context.Context, q queryer, workspaceID string) (domain.PersonalWorkspace, error) {
	var workspace domain.PersonalWorkspace
	err := q.QueryRow(ctx, `
		select id, key_version, recovery_generation, created_at
		from synapse_private.personal_workspaces where id = $1`, workspaceID).Scan(
		&workspace.ID, &workspace.KeyVersion, &workspace.RecoveryGeneration, &workspace.CreatedAt,
	)
	return workspace, err
}

func authByDevice(ctx context.Context, q queryer, deviceID string) (domain.AuthContext, error) {
	row := q.QueryRow(ctx, `
		select w.id, w.key_version, w.recovery_generation, w.created_at,
		       d.id, d.workspace_id, d.label, d.platform, d.role,
		       d.signing_public_key, d.encryption_public_key, d.created_at,
		       d.last_seen_at, d.revoked_at
		from synapse_private.trusted_devices d
		join synapse_private.personal_workspaces w on w.id = d.workspace_id
		where d.id = $1 and d.revoked_at is null`, deviceID)
	return scanAuth(row)
}

func pairingByID(ctx context.Context, q queryer, sessionID string, forUpdate bool) (domain.PairingSession, string, error) {
	lock := ""
	if forUpdate {
		lock = " for update"
	}
	row := q.QueryRow(ctx, `
		select id, pairing_code_hash, workspace_id, candidate_device_id, candidate_label,
		       candidate_platform, candidate_signing_public_key, candidate_encryption_public_key,
		       state, created_at, expires_at, approved_at, sealed_workspace_key
		from synapse_private.pairing_sessions where id = $1`+lock, sessionID)
	return scanPairing(row)
}

func insertDevice(ctx context.Context, tx pgx.Tx, device domain.TrustedDevice) error {
	_, err := tx.Exec(ctx, `
		insert into synapse_private.trusted_devices
		  (id, workspace_id, label, platform, role, signing_public_key,
		   encryption_public_key, created_at, last_seen_at, revoked_at)
		values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		device.ID,
		device.WorkspaceID,
		device.Label,
		device.Platform,
		device.Role,
		device.SigningPublicKey,
		device.EncryptionPublicKey,
		device.CreatedAt,
		device.LastSeenAt,
		device.RevokedAt,
	)
	return err
}

func insertOrReadEvent(ctx context.Context, tx pgx.Tx, event domain.EncryptedSyncEvent) (domain.EncryptedSyncEvent, error) {
	row := tx.QueryRow(ctx, `
		insert into synapse_private.encrypted_sync_events
		  (id, workspace_id, device_id, stream, entity_hash, kind, merge_policy,
		   logical_revision, key_version, idempotency_key, client_created_at,
		   nonce, cipher_text, authentication_tag, tombstone)
		values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
		on conflict (workspace_id, idempotency_key) do nothing
		returning server_sequence, id, workspace_id, device_id, stream, entity_hash,
		  kind, merge_policy, logical_revision, key_version, idempotency_key,
		  client_created_at, nonce, cipher_text, authentication_tag, tombstone, received_at`,
		event.ID,
		event.WorkspaceID,
		event.DeviceID,
		event.Stream,
		event.EntityHash,
		event.Kind,
		event.MergePolicy,
		event.LogicalRevision,
		event.KeyVersion,
		event.IdempotencyKey,
		event.ClientCreatedAt,
		event.Nonce,
		event.CipherText,
		event.AuthenticationTag,
		event.Tombstone,
	)
	stored, err := scanEvent(row)
	if !errors.Is(err, pgx.ErrNoRows) {
		return stored, err
	}
	row = tx.QueryRow(ctx, `
		select server_sequence, id, workspace_id, device_id, stream, entity_hash,
		       kind, merge_policy, logical_revision, key_version, idempotency_key,
		       client_created_at, nonce, cipher_text, authentication_tag, tombstone,
		       received_at
		from synapse_private.encrypted_sync_events
		where workspace_id = $1 and idempotency_key = $2`, event.WorkspaceID, event.IdempotencyKey)
	return scanEvent(row)
}

func scanAuth(row pgx.Row) (domain.AuthContext, error) {
	var auth domain.AuthContext
	var revokedAt *time.Time
	err := row.Scan(
		&auth.Workspace.ID,
		&auth.Workspace.KeyVersion,
		&auth.Workspace.RecoveryGeneration,
		&auth.Workspace.CreatedAt,
		&auth.Device.ID,
		&auth.Device.WorkspaceID,
		&auth.Device.Label,
		&auth.Device.Platform,
		&auth.Device.Role,
		&auth.Device.SigningPublicKey,
		&auth.Device.EncryptionPublicKey,
		&auth.Device.CreatedAt,
		&auth.Device.LastSeenAt,
		&revokedAt,
	)
	auth.Device.RevokedAt = revokedAt
	return auth, err
}

func scanDevice(row pgx.Row) (domain.TrustedDevice, error) {
	var device domain.TrustedDevice
	var revokedAt *time.Time
	err := row.Scan(
		&device.ID,
		&device.WorkspaceID,
		&device.Label,
		&device.Platform,
		&device.Role,
		&device.SigningPublicKey,
		&device.EncryptionPublicKey,
		&device.CreatedAt,
		&device.LastSeenAt,
		&revokedAt,
	)
	device.RevokedAt = revokedAt
	return device, err
}

func scanPairing(row pgx.Row) (domain.PairingSession, string, error) {
	var session domain.PairingSession
	var pairingCodeHash string
	var workspaceID *string
	var approvedAt *time.Time
	var sealedKey *string
	err := row.Scan(
		&session.ID,
		&pairingCodeHash,
		&workspaceID,
		&session.CandidateDeviceID,
		&session.CandidateLabel,
		&session.CandidatePlatform,
		&session.CandidateSigningPublicKey,
		&session.CandidateEncryptionPublicKey,
		&session.State,
		&session.CreatedAt,
		&session.ExpiresAt,
		&approvedAt,
		&sealedKey,
	)
	if workspaceID != nil {
		session.WorkspaceID = *workspaceID
	}
	session.ApprovedAt = approvedAt
	session.SealedWorkspaceKey = sealedKey
	return session, pairingCodeHash, err
}

func scanEvent(row pgx.Row) (domain.EncryptedSyncEvent, error) {
	var event domain.EncryptedSyncEvent
	var sequence int64
	var receivedAt time.Time
	err := row.Scan(
		&sequence,
		&event.ID,
		&event.WorkspaceID,
		&event.DeviceID,
		&event.Stream,
		&event.EntityHash,
		&event.Kind,
		&event.MergePolicy,
		&event.LogicalRevision,
		&event.KeyVersion,
		&event.IdempotencyKey,
		&event.ClientCreatedAt,
		&event.Nonce,
		&event.CipherText,
		&event.AuthenticationTag,
		&event.Tombstone,
		&receivedAt,
	)
	event.ServerSequence = &sequence
	event.ReceivedAt = &receivedAt
	return event, err
}

func scanPackage(row pgx.Row) (domain.SignedChapterPackage, error) {
	var pkg domain.SignedChapterPackage
	var signingKeyID pgtype.Text
	var sourceID pgtype.Text
	var releaseChannel pgtype.Text
	var canonicalSHA256 pgtype.Text
	var canonicalByteLength pgtype.Int8
	var transportSHA256 pgtype.Text
	var transportByteLength pgtype.Int8
	var signedAt pgtype.Timestamptz
	err := row.Scan(
		&pkg.ID,
		&pkg.ReleaseID,
		&pkg.CourseSourceKey,
		&pkg.ChapterSourceKey,
		&pkg.Ordinal,
		&pkg.ByteLength,
		&pkg.SHA256,
		&pkg.Signature,
		&pkg.ObjectKey,
		&signingKeyID,
		&sourceID,
		&releaseChannel,
		&canonicalSHA256,
		&canonicalByteLength,
		&transportSHA256,
		&transportByteLength,
		&signedAt,
	)
	if err != nil {
		return domain.SignedChapterPackage{}, err
	}
	fields := []bool{
		signingKeyID.Valid,
		sourceID.Valid,
		releaseChannel.Valid,
		canonicalSHA256.Valid,
		canonicalByteLength.Valid,
		transportSHA256.Valid,
		transportByteLength.Valid,
		signedAt.Valid,
	}
	complete := true
	empty := true
	for _, present := range fields {
		complete = complete && present
		empty = empty && !present
	}
	if !complete && !empty {
		return domain.SignedChapterPackage{}, errors.New("incomplete chapter package authorization")
	}
	if empty {
		return pkg, nil
	}
	if pkg.ReleaseID == "" ||
		releaseChannel.String != "internal" ||
		transportSHA256.String != pkg.SHA256 ||
		transportByteLength.Int64 != pkg.ByteLength ||
		canonicalByteLength.Int64 < 1 ||
		transportByteLength.Int64 < 1 {
		return domain.SignedChapterPackage{}, errors.New("invalid chapter package authorization")
	}
	pkg.Authorization = &domain.ChapterPackageAuthorization{
		SchemaVersion:       1,
		Domain:              "synapse.curriculum.release.v1",
		Algorithm:           "ed25519",
		KeyID:               signingKeyID.String,
		SourceID:            sourceID.String,
		ReleaseID:           pkg.ReleaseID,
		ReleaseChannel:      releaseChannel.String,
		CanonicalSHA256:     canonicalSHA256.String,
		CanonicalByteLength: canonicalByteLength.Int64,
		TransportSHA256:     transportSHA256.String,
		TransportByteLength: transportByteLength.Int64,
		SignedAt:            canonicalUTCString(signedAt.Time),
		Signature:           pkg.Signature,
	}
	return pkg, nil
}

func hashPairingCode(value string) string {
	hash := sha256.Sum256([]byte(value))
	return hex.EncodeToString(hash[:])
}

// canonicalUTCString mirrors Dart DateTime.toIso8601String for a UTC value:
// three mandatory millisecond digits plus three microsecond digits only when
// needed. PostgreSQL timestamptz preserves microsecond precision, so this is
// a lossless reconstruction of the signed timestamp representation.
func canonicalUTCString(value time.Time) string {
	value = value.UTC().Truncate(time.Microsecond)
	milliseconds := value.Nanosecond() / int(time.Millisecond)
	microseconds := (value.Nanosecond() / int(time.Microsecond)) % 1000
	result := value.Format("2006-01-02T15:04:05") + fmt.Sprintf(".%03d", milliseconds)
	if microseconds != 0 {
		result += fmt.Sprintf("%03d", microseconds)
	}
	return result + "Z"
}

func databaseError(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch pgErr.Code {
		case "23505":
			return ErrConflict
		case "23503":
			return ErrForbidden
		}
	}
	return err
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

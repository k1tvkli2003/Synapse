package store

import (
	"context"
	"crypto/subtle"
	"sort"
	"sync"
	"time"

	"synapse.local/personal-sync/internal/domain"
)

type Memory struct {
	mu             sync.Mutex
	workspace      *domain.PersonalWorkspace
	recoveryHash   string
	devices        map[string]domain.TrustedDevice
	pairings       map[string]domain.PairingSession
	nonces         map[string]time.Time
	tokens         map[string]domain.AccessToken
	events         []domain.EncryptedSyncEvent
	idempotency    map[string]int64
	manifest       *domain.ContentManifest
	contentPackage map[string]domain.SignedChapterPackage
}

func NewMemory() *Memory {
	return &Memory{
		devices:        map[string]domain.TrustedDevice{},
		pairings:       map[string]domain.PairingSession{},
		nonces:         map[string]time.Time{},
		tokens:         map[string]domain.AccessToken{},
		idempotency:    map[string]int64{},
		contentPackage: map[string]domain.SignedChapterPackage{},
	}
}

func (m *Memory) Bootstrap(_ context.Context, input domain.BootstrapInput) (domain.PersonalWorkspace, domain.TrustedDevice, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.workspace != nil {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, ErrAlreadyBootstrap
	}
	workspace := input.Workspace
	device := input.Device
	device.WorkspaceID = workspace.ID
	m.workspace = &workspace
	m.recoveryHash = input.RecoveryVerifierSHA256
	m.devices[device.ID] = device
	return workspace, device, nil
}

func (m *Memory) CreatePairing(_ context.Context, session domain.PairingSession) (domain.PairingSession, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, exists := m.pairings[session.ID]; exists {
		return domain.PairingSession{}, ErrConflict
	}
	m.pairings[session.ID] = session
	return session, nil
}

func (m *Memory) ApprovePairing(_ context.Context, workspaceID, sessionID, pairingCode, candidateEncryptionPublicKey, sealedKey string) (domain.PairingSession, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	session, ok := m.pairings[sessionID]
	if !ok {
		return domain.PairingSession{}, ErrNotFound
	}
	now := time.Now().UTC()
	if !now.Before(session.ExpiresAt) {
		session.State = "expired"
		m.pairings[sessionID] = session
		return domain.PairingSession{}, ErrExpired
	}
	if session.State != "pending" {
		return domain.PairingSession{}, ErrConflict
	}
	if subtle.ConstantTimeCompare([]byte(session.PairingCode), []byte(pairingCode)) != 1 || subtle.ConstantTimeCompare([]byte(session.CandidateEncryptionPublicKey), []byte(candidateEncryptionPublicKey)) != 1 {
		return domain.PairingSession{}, ErrForbidden
	}
	if m.workspace == nil || m.workspace.ID != workspaceID {
		return domain.PairingSession{}, ErrForbidden
	}
	session.State = "approved"
	session.WorkspaceID = workspaceID
	session.ApprovedAt = &now
	session.SealedWorkspaceKey = &sealedKey
	m.pairings[sessionID] = session
	return session, nil
}

func (m *Memory) PairingCandidate(_ context.Context, deviceID, sessionID, pairingCode string) (domain.TrustedDevice, domain.PersonalWorkspace, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	session, ok := m.pairings[sessionID]
	if !ok || session.CandidateDeviceID != deviceID {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrNotFound
	}
	if !time.Now().UTC().Before(session.ExpiresAt) {
		session.State = "expired"
		m.pairings[sessionID] = session
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrExpired
	}
	if session.State != "approved" || session.SealedWorkspaceKey == nil || m.workspace == nil || session.WorkspaceID != m.workspace.ID {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrForbidden
	}
	if subtle.ConstantTimeCompare([]byte(session.PairingCode), []byte(pairingCode)) != 1 {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrForbidden
	}
	return domain.TrustedDevice{
		ID:                  session.CandidateDeviceID,
		WorkspaceID:         session.WorkspaceID,
		Label:               session.CandidateLabel,
		Platform:            session.CandidatePlatform,
		Role:                "trusted",
		SigningPublicKey:    session.CandidateSigningPublicKey,
		EncryptionPublicKey: session.CandidateEncryptionPublicKey,
	}, *m.workspace, nil
}

func (m *Memory) ConsumePairing(_ context.Context, deviceID, sessionID, pairingCode string) (domain.PairingSession, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	session, ok := m.pairings[sessionID]
	if !ok || session.CandidateDeviceID != deviceID {
		return domain.PairingSession{}, ErrNotFound
	}
	if !time.Now().UTC().Before(session.ExpiresAt) {
		session.State = "expired"
		m.pairings[sessionID] = session
		return domain.PairingSession{}, ErrExpired
	}
	if session.State != "approved" || session.SealedWorkspaceKey == nil || session.WorkspaceID == "" {
		return domain.PairingSession{}, ErrForbidden
	}
	if subtle.ConstantTimeCompare([]byte(session.PairingCode), []byte(pairingCode)) != 1 {
		return domain.PairingSession{}, ErrForbidden
	}
	now := time.Now().UTC()
	session.State = "consumed"
	m.pairings[sessionID] = session
	m.devices[session.CandidateDeviceID] = domain.TrustedDevice{
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
	return session, nil
}

func (m *Memory) Device(_ context.Context, deviceID string) (domain.TrustedDevice, domain.PersonalWorkspace, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	device, ok := m.devices[deviceID]
	if !ok || device.RevokedAt != nil || m.workspace == nil {
		return domain.TrustedDevice{}, domain.PersonalWorkspace{}, ErrForbidden
	}
	return device, *m.workspace, nil
}

func (m *Memory) ConsumeNonce(_ context.Context, deviceID, nonceHash string, expiresAt time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	key := deviceID + ":" + nonceHash
	if expiry, exists := m.nonces[key]; exists && time.Now().Before(expiry) {
		return ErrReplay
	}
	m.nonces[key] = expiresAt
	return nil
}

func (m *Memory) SaveAccessToken(_ context.Context, token domain.AccessToken) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.tokens[token.Hash] = token
	return nil
}

func (m *Memory) AuthenticateToken(_ context.Context, tokenHash string, now time.Time) (domain.AuthContext, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	token, ok := m.tokens[tokenHash]
	if !ok || !now.Before(token.ExpiresAt) {
		return domain.AuthContext{}, ErrForbidden
	}
	device, ok := m.devices[token.DeviceID]
	if !ok || device.RevokedAt != nil || m.workspace == nil {
		return domain.AuthContext{}, ErrForbidden
	}
	device.LastSeenAt = now
	m.devices[device.ID] = device
	return domain.AuthContext{Workspace: *m.workspace, Device: device}, nil
}

func (m *Memory) ListDevices(_ context.Context, workspaceID string) ([]domain.TrustedDevice, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var result []domain.TrustedDevice
	for _, device := range m.devices {
		if device.WorkspaceID == workspaceID {
			result = append(result, device)
		}
	}
	sort.Slice(result, func(i, j int) bool { return result[i].CreatedAt.Before(result[j].CreatedAt) })
	return result, nil
}

func (m *Memory) RevokeDevice(_ context.Context, workspaceID, deviceID string, now time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	device, ok := m.devices[deviceID]
	if !ok || device.WorkspaceID != workspaceID {
		return ErrNotFound
	}
	if device.Role == "root" {
		return ErrForbidden
	}
	device.RevokedAt = &now
	m.devices[deviceID] = device
	for hash, token := range m.tokens {
		if token.DeviceID == deviceID {
			delete(m.tokens, hash)
		}
	}
	return nil
}

func (m *Memory) PushEvents(_ context.Context, auth domain.AuthContext, events []domain.EncryptedSyncEvent) ([]domain.EncryptedSyncEvent, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	result := make([]domain.EncryptedSyncEvent, 0, len(events))
	for _, event := range events {
		if event.WorkspaceID != auth.Workspace.ID || event.DeviceID != auth.Device.ID {
			return nil, ErrForbidden
		}
		key := auth.Workspace.ID + ":" + event.IdempotencyKey
		if sequence, exists := m.idempotency[key]; exists {
			copy := m.events[sequence-1]
			result = append(result, copy)
			continue
		}
		sequence := int64(len(m.events) + 1)
		event.ServerSequence = &sequence
		now := time.Now().UTC()
		event.ReceivedAt = &now
		m.events = append(m.events, event)
		m.idempotency[key] = sequence
		result = append(result, event)
	}
	return result, nil
}

func (m *Memory) PullEvents(_ context.Context, workspaceID string, after int64, limit int) ([]domain.EncryptedSyncEvent, int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var result []domain.EncryptedSyncEvent
	var next = after
	for _, event := range m.events {
		if event.WorkspaceID != workspaceID || event.ServerSequence == nil || *event.ServerSequence <= after {
			continue
		}
		result = append(result, event)
		next = *event.ServerSequence
		if len(result) == limit {
			break
		}
	}
	return result, next, nil
}

func (m *Memory) ContentManifest(_ context.Context, workspaceID string) (*domain.ContentManifest, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.workspace == nil || m.workspace.ID != workspaceID || m.manifest == nil {
		return nil, ErrNotFound
	}
	copy := *m.manifest
	return &copy, nil
}

func (m *Memory) ContentPackage(_ context.Context, workspaceID, packageID string) (domain.SignedChapterPackage, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.workspace == nil || m.workspace.ID != workspaceID {
		return domain.SignedChapterPackage{}, ErrForbidden
	}
	pkg, ok := m.contentPackage[packageID]
	if !ok {
		return domain.SignedChapterPackage{}, ErrNotFound
	}
	return pkg, nil
}

func (m *Memory) RotateRecovery(_ context.Context, input domain.RecoveryInput, now time.Time) (domain.PersonalWorkspace, domain.TrustedDevice, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.workspace == nil || m.workspace.ID != input.WorkspaceID || m.workspace.RecoveryGeneration != input.ExpectedGeneration {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, ErrConflict
	}
	if subtle.ConstantTimeCompare([]byte(m.recoveryHash), []byte(input.RecoveryVerifierSHA256)) != 1 {
		return domain.PersonalWorkspace{}, domain.TrustedDevice{}, ErrForbidden
	}
	for id, device := range m.devices {
		if device.RevokedAt == nil {
			device.RevokedAt = &now
			m.devices[id] = device
		}
	}
	m.tokens = map[string]domain.AccessToken{}
	workspace := *m.workspace
	workspace.RecoveryGeneration++
	workspace.KeyVersion++
	m.workspace = &workspace
	m.recoveryHash = input.NewRecoveryVerifierHash
	root := input.NewRootDevice
	root.WorkspaceID = workspace.ID
	root.Role = "root"
	root.CreatedAt = now
	root.LastSeenAt = now
	root.RevokedAt = nil
	m.devices[root.ID] = root
	return workspace, root, nil
}

func (m *Memory) SetContent(manifest domain.ContentManifest) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.manifest = &manifest
	for _, pkg := range manifest.Packages {
		m.contentPackage[pkg.ID] = pkg
	}
}

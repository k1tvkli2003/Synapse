package api

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"synapse.local/personal-sync/internal/config"
	"synapse.local/personal-sync/internal/domain"
	"synapse.local/personal-sync/internal/objectstore"
	"synapse.local/personal-sync/internal/store"
)

func TestPersonalGatewayPairsAndSyncsIdempotently(t *testing.T) {
	t.Parallel()
	now := time.Now().UTC().Round(0)
	bootstrapToken := "synapse-private-bootstrap-token"
	bootstrapHash := sha256.Sum256([]byte(bootstrapToken))
	server := New(config.Config{
		BootstrapTokenSHA256:   hex.EncodeToString(bootstrapHash[:]),
		AccessTokenTTL:         15 * time.Minute,
		PairingTTL:             5 * time.Minute,
		DeviceSignatureMaxSkew: 90 * time.Second,
		MaxRequestBytes:        1 << 20,
	}, store.NewMemory(), objectstore.Memory{}, nil)
	server.now = func() time.Time { return now }
	handler := server.Handler()

	root, rootPrivate := testDevice(t, "device_root", "Windows")
	root.Platform = "windows"
	bootstrapBody := map[string]any{
		"bootstrapToken":         bootstrapToken,
		"recoveryVerifierSha256": strings.Repeat("a", 64),
		"device":                 root,
	}
	status, body := callJSON(t, handler, http.MethodPost, "/v1/bootstrap/redeem", bootstrapBody, "")
	if status != http.StatusOK {
		t.Fatalf("bootstrap status = %d, body = %s", status, body)
	}
	var bootstrap struct {
		Workspace domain.PersonalWorkspace `json:"workspace"`
		Device    domain.TrustedDevice     `json:"device"`
	}
	decodeResponse(t, body, &bootstrap)
	if bootstrap.Workspace.ID == "" || bootstrap.Device.Role != "root" {
		t.Fatalf("unexpected bootstrap response: %+v", bootstrap)
	}

	rootToken := issueDeviceToken(t, handler, root.ID, rootPrivate, now, nil, nil)
	candidate, candidatePrivate := testDevice(t, "device_android", "Android")
	candidate.Platform = "android"
	status, body = callJSON(t, handler, http.MethodPost, "/v1/pairing/sessions", map[string]any{"candidate": candidate}, "")
	if status != http.StatusOK {
		t.Fatalf("create pairing status = %d, body = %s", status, body)
	}
	var pairing struct {
		Session domain.PairingSession `json:"session"`
	}
	decodeResponse(t, body, &pairing)
	if pairing.Session.ID == "" || pairing.Session.PairingCode == "" {
		t.Fatalf("pairing session does not contain a short-lived proof: %+v", pairing.Session)
	}

	status, body = callJSON(t, handler, http.MethodPost, "/v1/pairing/"+pairing.Session.ID+"/approve", map[string]any{
		"pairingCode":                  pairing.Session.PairingCode,
		"candidateEncryptionPublicKey": candidate.EncryptionPublicKey,
		"sealedWorkspaceKey":           strings.Repeat("z", 64),
	}, rootToken)
	if status != http.StatusOK {
		t.Fatalf("approve pairing status = %d, body = %s", status, body)
	}

	candidateToken := issueDeviceToken(t, handler, candidate.ID, candidatePrivate, now, &pairing.Session.ID, &pairing.Session.PairingCode)
	status, body = callJSON(t, handler, http.MethodGet, "/v1/devices", nil, candidateToken)
	if status != http.StatusOK {
		t.Fatalf("list devices status = %d, body = %s", status, body)
	}
	var devices struct {
		Devices []domain.TrustedDevice `json:"devices"`
	}
	decodeResponse(t, body, &devices)
	if len(devices.Devices) != 2 {
		t.Fatalf("trusted devices = %d, want 2", len(devices.Devices))
	}

	otherNonce := "candidate-repeat-nonce-000000000000000000000000"
	status, body = signedDeviceTokenRequest(t, handler, candidate.ID, candidatePrivate, now, otherNonce, &pairing.Session.ID, &pairing.Session.PairingCode)
	if status != http.StatusForbidden {
		t.Fatalf("consumed pairing status = %d, want 403, body = %s", status, body)
	}

	event := domain.EncryptedSyncEvent{
		ID:                "event_001",
		WorkspaceID:       bootstrap.Workspace.ID,
		DeviceID:          candidate.ID,
		Stream:            "learner.progress",
		EntityHash:        strings.Repeat("b", 64),
		Kind:              "progress",
		MergePolicy:       "monotonicMaximum",
		LogicalRevision:   1,
		KeyVersion:        1,
		IdempotencyKey:    "event_idempotency_001",
		ClientCreatedAt:   now,
		Nonce:             "nonce",
		CipherText:        "ciphertext",
		AuthenticationTag: "tag",
	}
	firstSequence := pushOneEvent(t, handler, candidateToken, event)
	secondSequence := pushOneEvent(t, handler, candidateToken, event)
	if firstSequence != secondSequence {
		t.Fatalf("idempotent push changed sequence from %d to %d", firstSequence, secondSequence)
	}

	status, body = callJSON(t, handler, http.MethodPost, "/v1/sync/pull", map[string]any{"afterSequence": 0, "limit": 20}, candidateToken)
	if status != http.StatusOK {
		t.Fatalf("pull status = %d, body = %s", status, body)
	}
	var pull struct {
		Events       []domain.EncryptedSyncEvent `json:"events"`
		NextSequence int64                       `json:"nextSequence"`
	}
	decodeResponse(t, body, &pull)
	if len(pull.Events) != 1 || pull.NextSequence != firstSequence {
		t.Fatalf("unexpected pull result: %+v", pull)
	}
}

func TestBootstrapTokenCanOnlyCreateOnePersonalWorkspace(t *testing.T) {
	t.Parallel()
	handler, now, bootstrapToken := newTestHandler(t)
	root, _ := testDevice(t, "bootstrap_root", "Windows")
	root.Platform = "windows"
	body := map[string]any{
		"bootstrapToken":         bootstrapToken,
		"recoveryVerifierSha256": strings.Repeat("a", 64),
		"device":                 root,
	}

	status, response := callJSON(t, handler, http.MethodPost, "/v1/bootstrap/redeem", body, "")
	if status != http.StatusOK {
		t.Fatalf("first bootstrap status = %d, body = %s", status, response)
	}
	status, response = callJSON(t, handler, http.MethodPost, "/v1/bootstrap/redeem", body, "")
	if status != http.StatusConflict {
		t.Fatalf("second bootstrap status = %d, want 409, body = %s", status, response)
	}
	_ = now
}

func TestPairingProofBindsTheExactCandidateAndDoesNotTrustWrongCode(t *testing.T) {
	t.Parallel()
	handler, now, bootstrapToken := newTestHandler(t)
	workspace, root, rootPrivate, rootToken := bootstrapTestRoot(t, handler, now, bootstrapToken)
	_ = workspace
	candidate, candidatePrivate := testDevice(t, "pairing_candidate", "Android")
	candidate.Platform = "android"
	status, body := callJSON(t, handler, http.MethodPost, "/v1/pairing/sessions", map[string]any{"candidate": candidate}, "")
	if status != http.StatusOK {
		t.Fatalf("create pairing status = %d, body = %s", status, body)
	}
	var pairing struct {
		Session domain.PairingSession `json:"session"`
	}
	decodeResponse(t, body, &pairing)

	status, body = callJSON(t, handler, http.MethodPost, "/v1/pairing/"+pairing.Session.ID+"/approve", map[string]any{
		"pairingCode":                  pairing.Session.PairingCode,
		"candidateEncryptionPublicKey": candidate.EncryptionPublicKey,
		"sealedWorkspaceKey":           strings.Repeat("z", 64),
	}, rootToken)
	if status != http.StatusOK {
		t.Fatalf("approve pairing status = %d, body = %s", status, body)
	}

	wrongCode := "000-000"
	if wrongCode == pairing.Session.PairingCode {
		wrongCode = "999-999"
	}
	status, body = signedDeviceTokenRequest(t, handler, candidate.ID, candidatePrivate, now, "candidate-wrong-code-nonce-000000000000000", &pairing.Session.ID, &wrongCode)
	if status != http.StatusForbidden {
		t.Fatalf("wrong pairing code status = %d, want 403, body = %s", status, body)
	}

	status, body = callJSON(t, handler, http.MethodGet, "/v1/devices", nil, rootToken)
	if status != http.StatusOK {
		t.Fatalf("list root devices status = %d, body = %s", status, body)
	}
	var devices struct {
		Devices []domain.TrustedDevice `json:"devices"`
	}
	decodeResponse(t, body, &devices)
	if len(devices.Devices) != 1 || devices.Devices[0].ID != root.ID {
		t.Fatalf("wrong pairing code trusted candidate: %+v", devices.Devices)
	}

	status, body = signedDeviceTokenRequest(t, handler, candidate.ID, candidatePrivate, now, "candidate-valid-code-nonce-000000000000000", &pairing.Session.ID, &pairing.Session.PairingCode)
	if status != http.StatusOK {
		t.Fatalf("valid pairing code status = %d, body = %s", status, body)
	}
	_ = rootPrivate
}

func TestRevokedDeviceLosesSyncAndContentAccess(t *testing.T) {
	t.Parallel()
	handler, now, bootstrapToken := newTestHandler(t)
	_, root, rootPrivate, rootToken := bootstrapTestRoot(t, handler, now, bootstrapToken)
	candidate, candidatePrivate := testDevice(t, "revoked_candidate", "Android")
	candidate.Platform = "android"
	status, body := callJSON(t, handler, http.MethodPost, "/v1/pairing/sessions", map[string]any{"candidate": candidate}, "")
	if status != http.StatusOK {
		t.Fatalf("create pairing status = %d, body = %s", status, body)
	}
	var pairing struct {
		Session domain.PairingSession `json:"session"`
	}
	decodeResponse(t, body, &pairing)
	status, body = callJSON(t, handler, http.MethodPost, "/v1/pairing/"+pairing.Session.ID+"/approve", map[string]any{
		"pairingCode":                  pairing.Session.PairingCode,
		"candidateEncryptionPublicKey": candidate.EncryptionPublicKey,
		"sealedWorkspaceKey":           strings.Repeat("z", 64),
	}, rootToken)
	if status != http.StatusOK {
		t.Fatalf("approve pairing status = %d, body = %s", status, body)
	}
	candidateToken := issueDeviceToken(t, handler, candidate.ID, candidatePrivate, now, &pairing.Session.ID, &pairing.Session.PairingCode)

	status, body = callJSON(t, handler, http.MethodDelete, "/v1/devices/"+candidate.ID, nil, rootToken)
	if status != http.StatusOK {
		t.Fatalf("revoke status = %d, body = %s", status, body)
	}
	for _, target := range []string{"/v1/sync/pull", "/v1/content/manifest"} {
		payload := any(nil)
		if target == "/v1/sync/pull" {
			payload = map[string]any{"afterSequence": 0, "limit": 20}
		}
		status, body = callJSON(t, handler, map[bool]string{true: http.MethodPost, false: http.MethodGet}[target == "/v1/sync/pull"], target, payload, candidateToken)
		if status != http.StatusForbidden {
			t.Fatalf("revoked device %s status = %d, want 403, body = %s", target, status, body)
		}
	}
	_ = root
	_ = rootPrivate
}

func TestContentTransportServesCompleteV2EnvelopeAndImmutableBytes(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, time.July, 27, 12, 30, 0, 0, time.UTC)
	bootstrapToken := "synapse-private-bootstrap-token"
	bootstrapHash := sha256.Sum256([]byte(bootstrapToken))
	payload := []byte(`{"schemaVersion":1,"chapter":"respiratory_001"}`)
	payloadHash := sha256.Sum256(payload)
	objectKey := "internal/release_respiratory_001/chapter_001.json"
	memory := store.NewMemory()
	server := New(config.Config{
		BootstrapTokenSHA256:   hex.EncodeToString(bootstrapHash[:]),
		AccessTokenTTL:         15 * time.Minute,
		PairingTTL:             5 * time.Minute,
		DeviceSignatureMaxSkew: 90 * time.Second,
		MaxRequestBytes:        1 << 20,
	}, memory, objectstore.Memory{objectKey: payload}, nil)
	server.now = func() time.Time { return now }
	handler := server.Handler()
	workspace, _, _, rootToken := bootstrapTestRoot(t, handler, now, bootstrapToken)

	pkg := domain.SignedChapterPackage{
		ID:               "pkg_respiratory_001",
		ReleaseID:        "release_respiratory_001",
		CourseSourceKey:  "part_07",
		ChapterSourceKey: "part_07/chapter_001",
		Ordinal:          1,
		ByteLength:       int64(len(payload)),
		SHA256:           hex.EncodeToString(payloadHash[:]),
		Signature:        "c2lnbmF0dXJl",
		ObjectKey:        objectKey,
		Authorization: &domain.ChapterPackageAuthorization{
			SchemaVersion:       1,
			Domain:              "synapse.curriculum.release.v1",
			Algorithm:           "ed25519",
			KeyID:               "k1_internal_2026",
			SourceID:            "simulated_harrison",
			ReleaseID:           "release_respiratory_001",
			ReleaseChannel:      "internal",
			CanonicalSHA256:     strings.Repeat("a", 64),
			CanonicalByteLength: int64(len(payload)),
			TransportSHA256:     hex.EncodeToString(payloadHash[:]),
			TransportByteLength: int64(len(payload)),
			SignedAt:            "2026-07-27T12:30:00.000Z",
			Signature:           "c2lnbmF0dXJl",
		},
	}
	memory.SetContent(domain.ContentManifest{
		SchemaVersion: 2,
		Head: domain.PersonalChannelHead{
			Channel:        "internal",
			ReleaseID:      pkg.ReleaseID,
			ManifestSHA256: strings.Repeat("b", 64),
			Sequence:       1,
			UpdatedAt:      now,
		},
		Packages: []domain.SignedChapterPackage{pkg},
	})

	status, body := callJSON(t, handler, http.MethodGet, "/v1/content/manifest", nil, rootToken)
	if status != http.StatusOK {
		t.Fatalf("content manifest status = %d, body = %s", status, body)
	}
	var manifest domain.ContentManifest
	decodeResponse(t, body, &manifest)
	if manifest.SchemaVersion != 2 || len(manifest.Packages) != 1 || manifest.Packages[0].Authorization == nil {
		t.Fatalf("gateway lost the v2 authorization envelope: %+v", manifest)
	}
	if manifest.Packages[0].Authorization.TransportSHA256 != pkg.SHA256 {
		t.Fatalf("gateway changed envelope transport hash: %+v", manifest.Packages[0].Authorization)
	}

	request := httptest.NewRequest(http.MethodGet, "/v1/content/manifest", nil)
	request.Header.Set("Authorization", "Bearer "+rootToken)
	request.Header.Set("If-None-Match", `"`+strings.Repeat("b", 64)+`"`)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusNotModified {
		t.Fatalf("manifest conditional request status = %d, body = %s", response.Code, response.Body.Bytes())
	}

	status, body = callJSON(t, handler, http.MethodGet, "/v1/content/packages/"+pkg.ID, nil, rootToken)
	if status != http.StatusOK {
		t.Fatalf("content package status = %d, body = %s", status, body)
	}
	if string(body) != string(payload) {
		t.Fatalf("content package bytes = %q, want %q", body, payload)
	}
	_ = workspace
}

func TestRecoveryRotationRevokesOldRootAndIssuesNewGeneration(t *testing.T) {
	t.Parallel()
	handler, now, bootstrapToken := newTestHandler(t)
	workspace, _, _, rootToken := bootstrapTestRoot(t, handler, now, bootstrapToken)
	recoveryRoot, recoveryPrivate := testDevice(t, "recovery_root", "Windows")
	recoveryRoot.Platform = "windows"
	status, body := callJSON(t, handler, http.MethodPost, "/v1/recovery/rotate", map[string]any{
		"workspaceId":               workspace.ID,
		"expectedGeneration":        workspace.RecoveryGeneration,
		"recoveryVerifierSha256":    strings.Repeat("a", 64),
		"newRecoveryVerifierSha256": strings.Repeat("b", 64),
		"newRootDevice":             recoveryRoot,
	}, "")
	if status != http.StatusOK {
		t.Fatalf("recovery rotation status = %d, body = %s", status, body)
	}
	var rotation struct {
		Workspace domain.PersonalWorkspace `json:"workspace"`
		Device    domain.TrustedDevice     `json:"device"`
	}
	decodeResponse(t, body, &rotation)
	if rotation.Workspace.RecoveryGeneration != workspace.RecoveryGeneration+1 || rotation.Workspace.KeyVersion != workspace.KeyVersion+1 || rotation.Device.ID != recoveryRoot.ID || rotation.Device.Role != "root" {
		t.Fatalf("unexpected rotation response: %+v", rotation)
	}

	status, body = callJSON(t, handler, http.MethodGet, "/v1/devices", nil, rootToken)
	if status != http.StatusForbidden {
		t.Fatalf("old root token survived recovery: status = %d, body = %s", status, body)
	}
	newRootToken := issueDeviceToken(t, handler, recoveryRoot.ID, recoveryPrivate, now, nil, nil)
	status, body = callJSON(t, handler, http.MethodGet, "/v1/devices", nil, newRootToken)
	if status != http.StatusOK {
		t.Fatalf("new recovery root cannot authenticate: status = %d, body = %s", status, body)
	}
}

func newTestHandler(t *testing.T) (http.Handler, time.Time, string) {
	t.Helper()
	now := time.Now().UTC().Round(0)
	bootstrapToken := "synapse-private-bootstrap-token"
	bootstrapHash := sha256.Sum256([]byte(bootstrapToken))
	server := New(config.Config{
		BootstrapTokenSHA256:   hex.EncodeToString(bootstrapHash[:]),
		AccessTokenTTL:         15 * time.Minute,
		PairingTTL:             5 * time.Minute,
		DeviceSignatureMaxSkew: 90 * time.Second,
		MaxRequestBytes:        1 << 20,
	}, store.NewMemory(), objectstore.Memory{}, nil)
	server.now = func() time.Time { return now }
	return server.Handler(), now, bootstrapToken
}

func bootstrapTestRoot(t *testing.T, handler http.Handler, now time.Time, bootstrapToken string) (domain.PersonalWorkspace, domain.TrustedDevice, ed25519.PrivateKey, string) {
	t.Helper()
	root, rootPrivate := testDevice(t, "test_root", "Windows")
	root.Platform = "windows"
	status, body := callJSON(t, handler, http.MethodPost, "/v1/bootstrap/redeem", map[string]any{
		"bootstrapToken":         bootstrapToken,
		"recoveryVerifierSha256": strings.Repeat("a", 64),
		"device":                 root,
	}, "")
	if status != http.StatusOK {
		t.Fatalf("bootstrap root status = %d, body = %s", status, body)
	}
	var bootstrap struct {
		Workspace domain.PersonalWorkspace `json:"workspace"`
		Device    domain.TrustedDevice     `json:"device"`
	}
	decodeResponse(t, body, &bootstrap)
	return bootstrap.Workspace, bootstrap.Device, rootPrivate, issueDeviceToken(t, handler, root.ID, rootPrivate, now, nil, nil)
}

func pushOneEvent(t *testing.T, handler http.Handler, token string, event domain.EncryptedSyncEvent) int64 {
	t.Helper()
	status, body := callJSON(t, handler, http.MethodPost, "/v1/sync/push", map[string]any{"events": []domain.EncryptedSyncEvent{event}}, token)
	if status != http.StatusOK {
		t.Fatalf("push status = %d, body = %s", status, body)
	}
	var push struct {
		Events []domain.EncryptedSyncEvent `json:"events"`
	}
	decodeResponse(t, body, &push)
	if len(push.Events) != 1 || push.Events[0].ServerSequence == nil {
		t.Fatalf("unexpected push response: %+v", push)
	}
	return *push.Events[0].ServerSequence
}

func issueDeviceToken(t *testing.T, handler http.Handler, deviceID string, privateKey ed25519.PrivateKey, now time.Time, pairingID, pairingCode *string) string {
	t.Helper()
	status, body := signedDeviceTokenRequest(t, handler, deviceID, privateKey, now, "challenge-nonce-0000000000000000000000000", pairingID, pairingCode)
	if status != http.StatusOK {
		t.Fatalf("issue token status = %d, body = %s", status, body)
	}
	var result struct {
		AccessToken        string  `json:"accessToken"`
		SealedWorkspaceKey *string `json:"sealedWorkspaceKey"`
	}
	decodeResponse(t, body, &result)
	if result.AccessToken == "" {
		t.Fatal("device token was empty")
	}
	if pairingID != nil && result.SealedWorkspaceKey == nil {
		t.Fatal("paired device did not receive the sealed workspace key")
	}
	return result.AccessToken
}

func signedDeviceTokenRequest(t *testing.T, handler http.Handler, deviceID string, privateKey ed25519.PrivateKey, now time.Time, nonce string, pairingID, pairingCode *string) (int, []byte) {
	t.Helper()
	timestamp := now.Format(time.RFC3339Nano)
	message := "synapse-device-token-v1\n" + deviceID + "\n" + nonce + "\n" + timestamp
	signature := ed25519.Sign(privateKey, []byte(message))
	payload := map[string]any{
		"deviceId":  deviceID,
		"nonce":     nonce,
		"timestamp": timestamp,
		"signature": base64.RawURLEncoding.EncodeToString(signature),
	}
	if pairingID != nil {
		payload["pairingSessionId"] = *pairingID
		payload["pairingCode"] = *pairingCode
	}
	return callJSON(t, handler, http.MethodPost, "/v1/device-token", payload, "")
}

func testDevice(t *testing.T, id, _ string) (domain.TrustedDevice, ed25519.PrivateKey) {
	t.Helper()
	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	encryptionKey := make([]byte, 32)
	if _, err := rand.Read(encryptionKey); err != nil {
		t.Fatal(err)
	}
	return domain.TrustedDevice{
		ID:                  id,
		Label:               id,
		SigningPublicKey:    base64.RawURLEncoding.EncodeToString(publicKey),
		EncryptionPublicKey: base64.RawURLEncoding.EncodeToString(encryptionKey),
	}, privateKey
}

func callJSON(t *testing.T, handler http.Handler, method, target string, payload any, token string) (int, []byte) {
	t.Helper()
	var body bytes.Buffer
	if payload != nil {
		if err := json.NewEncoder(&body).Encode(payload); err != nil {
			t.Fatal(err)
		}
	}
	request := httptest.NewRequest(method, target, &body)
	if payload != nil {
		request.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response.Code, response.Body.Bytes()
}

func decodeResponse(t *testing.T, body []byte, target any) {
	t.Helper()
	if err := json.Unmarshal(body, target); err != nil {
		t.Fatalf("decode response %s: %v", body, err)
	}
}

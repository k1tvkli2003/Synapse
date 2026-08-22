package api

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"synapse.local/personal-sync/internal/config"
	"synapse.local/personal-sync/internal/domain"
	"synapse.local/personal-sync/internal/objectstore"
	"synapse.local/personal-sync/internal/store"
)

var (
	idPattern          = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$`)
	tokenPattern       = regexp.MustCompile(`^[A-Za-z0-9_-]{20,200}$`)
	pairingCodePattern = regexp.MustCompile(`^[0-9]{3}-[0-9]{3}$`)
	sha256Pattern      = regexp.MustCompile(`^[0-9a-f]{64}$`)
	streamPattern      = regexp.MustCompile(`^[a-z0-9][a-z0-9._-]{0,79}$`)
	platforms          = map[string]bool{"windows": true, "android": true, "web": true}
	eventKinds         = map[string]bool{"attempt": true, "reward": true, "studyHistory": true, "progress": true, "mastery": true, "note": true, "bookmark": true, "readingPosition": true, "setting": true, "deviceReceipt": true}
	mergePolicies      = map[string]bool{"appendOnly": true, "monotonicMaximum": true, "lastWriteWins": true, "tombstoneWins": true}
	errBodyTooLarge    = errors.New("request body too large")
)

type Server struct {
	cfg     config.Config
	store   store.Store
	objects objectstore.Store
	log     *slog.Logger
	now     func() time.Time
	limits  *rateLimiter
}

func New(cfg config.Config, persistence store.Store, objects objectstore.Store, logger *slog.Logger) *Server {
	if logger == nil {
		logger = slog.Default()
	}
	return &Server{
		cfg:     cfg,
		store:   persistence,
		objects: objects,
		log:     logger,
		now:     func() time.Time { return time.Now().UTC() },
		limits:  newRateLimiter(60, time.Minute),
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("POST /v1/bootstrap/redeem", s.bootstrap)
	mux.HandleFunc("POST /v1/pairing/sessions", s.createPairing)
	mux.HandleFunc("POST /v1/pairing/{id}/approve", s.approvePairing)
	mux.HandleFunc("POST /v1/device-token", s.deviceToken)
	mux.HandleFunc("GET /v1/devices", s.listDevices)
	mux.HandleFunc("DELETE /v1/devices/{id}", s.revokeDevice)
	mux.HandleFunc("POST /v1/sync/push", s.pushSync)
	mux.HandleFunc("POST /v1/sync/pull", s.pullSync)
	mux.HandleFunc("GET /v1/content/manifest", s.contentManifest)
	mux.HandleFunc("GET /v1/content/packages/{id}", s.contentPackage)
	mux.HandleFunc("POST /v1/recovery/rotate", s.rotateRecovery)
	return s.recover(s.cors(s.requestLog(s.limit(mux))))
}

func (s *Server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "service": "synapse-personal-sync"})
}

func (s *Server) bootstrap(w http.ResponseWriter, r *http.Request) {
	var request struct {
		BootstrapToken         string               `json:"bootstrapToken"`
		RecoveryVerifierSHA256 string               `json:"recoveryVerifierSha256"`
		Device                 domain.TrustedDevice `json:"device"`
	}
	if err := s.decode(w, r, &request); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	hash := sha256.Sum256([]byte(request.BootstrapToken))
	if subtle.ConstantTimeCompare([]byte(hex.EncodeToString(hash[:])), []byte(s.cfg.BootstrapTokenSHA256)) != 1 {
		s.writeError(w, r, http.StatusForbidden, "invalid_bootstrap_token", "The one-time bootstrap token is invalid.")
		return
	}
	if !sha256Pattern.MatchString(request.RecoveryVerifierSHA256) {
		s.writeError(w, r, http.StatusBadRequest, "invalid_recovery_verifier", "The recovery verifier is invalid.")
		return
	}
	now := s.now()
	workspace := domain.PersonalWorkspace{
		ID:                 opaqueID("wrk", 16),
		KeyVersion:         1,
		RecoveryGeneration: 1,
		CreatedAt:          now,
	}
	device := request.Device
	device.WorkspaceID = workspace.ID
	device.Role = "root"
	device.CreatedAt = now
	device.LastSeenAt = now
	device.RevokedAt = nil
	if err := validateDevice(device); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_device", err.Error())
		return
	}
	workspace, device, err := s.store.Bootstrap(r.Context(), domain.BootstrapInput{
		Workspace:              workspace,
		RecoveryVerifierSHA256: request.RecoveryVerifierSHA256,
		Device:                 device,
	})
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"workspace": workspace, "device": device})
}

func (s *Server) createPairing(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Candidate domain.TrustedDevice `json:"candidate"`
	}
	if err := s.decode(w, r, &request); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	candidate := request.Candidate
	candidate.WorkspaceID = "pending"
	candidate.Role = "trusted"
	if err := validateDevice(candidate); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_device", err.Error())
		return
	}
	now := s.now()
	session := domain.PairingSession{
		ID:                           opaqueID("pair", 16),
		PairingCode:                  pairingCode(),
		CandidateDeviceID:            candidate.ID,
		CandidateLabel:               candidate.Label,
		CandidatePlatform:            candidate.Platform,
		CandidateSigningPublicKey:    candidate.SigningPublicKey,
		CandidateEncryptionPublicKey: candidate.EncryptionPublicKey,
		State:                        "pending",
		CreatedAt:                    now,
		ExpiresAt:                    now.Add(s.cfg.PairingTTL),
	}
	session, err := s.store.CreatePairing(r.Context(), session)
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"session": session})
}

func (s *Server) approvePairing(w http.ResponseWriter, r *http.Request) {
	auth, ok := s.authenticate(w, r)
	if !ok {
		return
	}
	var request struct {
		PairingCode                  string `json:"pairingCode"`
		CandidateEncryptionPublicKey string `json:"candidateEncryptionPublicKey"`
		SealedWorkspaceKey           string `json:"sealedWorkspaceKey"`
	}
	if err := s.decode(w, r, &request); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if !pairingCodePattern.MatchString(request.PairingCode) {
		s.writeError(w, r, http.StatusBadRequest, "invalid_pairing_proof", "The pairing proof is invalid.")
		return
	}
	if _, err := decodeKey(request.CandidateEncryptionPublicKey, 32); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_pairing_candidate", "The pairing candidate is invalid.")
		return
	}
	if len(request.SealedWorkspaceKey) < 40 || len(request.SealedWorkspaceKey) > 4096 {
		s.writeError(w, r, http.StatusBadRequest, "invalid_sealed_workspace_key", "The sealed workspace key is invalid.")
		return
	}
	session, err := s.store.ApprovePairing(
		r.Context(),
		auth.Workspace.ID,
		r.PathValue("id"),
		request.PairingCode,
		request.CandidateEncryptionPublicKey,
		request.SealedWorkspaceKey,
	)
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"session": session})
}

func (s *Server) deviceToken(w http.ResponseWriter, r *http.Request) {
	var request struct {
		DeviceID         string  `json:"deviceId"`
		Nonce            string  `json:"nonce"`
		Timestamp        string  `json:"timestamp"`
		Signature        string  `json:"signature"`
		PairingSessionID *string `json:"pairingSessionId"`
		PairingCode      *string `json:"pairingCode"`
	}
	if err := s.decode(w, r, &request); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if !idPattern.MatchString(request.DeviceID) || !tokenPattern.MatchString(request.Nonce) {
		s.writeError(w, r, http.StatusBadRequest, "invalid_device_challenge", "The device challenge is invalid.")
		return
	}
	timestamp, err := time.Parse(time.RFC3339Nano, request.Timestamp)
	if err != nil || absDuration(s.now().Sub(timestamp)) > s.cfg.DeviceSignatureMaxSkew {
		s.writeError(w, r, http.StatusUnauthorized, "stale_device_challenge", "The device challenge is outside the accepted time window.")
		return
	}
	if (request.PairingSessionID == nil) != (request.PairingCode == nil) {
		s.writeError(w, r, http.StatusBadRequest, "invalid_pairing_proof", "Pairing session and code must be supplied together.")
		return
	}
	var device domain.TrustedDevice
	var workspace domain.PersonalWorkspace
	if request.PairingSessionID != nil {
		if !idPattern.MatchString(*request.PairingSessionID) || !pairingCodePattern.MatchString(*request.PairingCode) {
			s.writeError(w, r, http.StatusBadRequest, "invalid_pairing_proof", "The pairing proof is invalid.")
			return
		}
		device, workspace, err = s.store.PairingCandidate(r.Context(), request.DeviceID, *request.PairingSessionID, *request.PairingCode)
	} else {
		device, workspace, err = s.store.Device(r.Context(), request.DeviceID)
	}
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	publicKey, err := decodeKey(device.SigningPublicKey, ed25519.PublicKeySize)
	if err != nil {
		s.writeError(w, r, http.StatusUnauthorized, "invalid_device_key", "The registered device key is invalid.")
		return
	}
	signature, err := decodeBase64URL(request.Signature)
	if err != nil || len(signature) != ed25519.SignatureSize {
		s.writeError(w, r, http.StatusUnauthorized, "invalid_device_signature", "The device signature is invalid.")
		return
	}
	message := "synapse-device-token-v1\n" + request.DeviceID + "\n" + request.Nonce + "\n" + request.Timestamp
	if !ed25519.Verify(ed25519.PublicKey(publicKey), []byte(message), signature) {
		s.writeError(w, r, http.StatusUnauthorized, "invalid_device_signature", "The device signature is invalid.")
		return
	}
	nonceHash := sha256.Sum256([]byte(request.Nonce))
	if err := s.store.ConsumeNonce(r.Context(), request.DeviceID, hex.EncodeToString(nonceHash[:]), timestamp.Add(s.cfg.DeviceSignatureMaxSkew)); err != nil {
		s.storeError(w, r, err)
		return
	}
	response := map[string]any{}
	if request.PairingSessionID != nil {
		session, err := s.store.ConsumePairing(r.Context(), request.DeviceID, *request.PairingSessionID, *request.PairingCode)
		if err != nil {
			s.storeError(w, r, err)
			return
		}
		device, workspace, err = s.store.Device(r.Context(), request.DeviceID)
		if err != nil {
			s.storeError(w, r, err)
			return
		}
		response["sealedWorkspaceKey"] = session.SealedWorkspaceKey
	}
	rawToken := randomToken(32)
	tokenHash := sha256.Sum256([]byte(rawToken))
	expiresAt := s.now().Add(s.cfg.AccessTokenTTL)
	if err := s.store.SaveAccessToken(r.Context(), domain.AccessToken{
		Hash:      hex.EncodeToString(tokenHash[:]),
		DeviceID:  request.DeviceID,
		ExpiresAt: expiresAt,
	}); err != nil {
		s.storeError(w, r, err)
		return
	}
	response["accessToken"] = rawToken
	response["expiresAt"] = expiresAt
	response["workspace"] = workspace
	response["device"] = device
	writeJSON(w, http.StatusOK, response)
}

func (s *Server) listDevices(w http.ResponseWriter, r *http.Request) {
	auth, ok := s.authenticate(w, r)
	if !ok {
		return
	}
	devices, err := s.store.ListDevices(r.Context(), auth.Workspace.ID)
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"devices": devices})
}

func (s *Server) revokeDevice(w http.ResponseWriter, r *http.Request) {
	auth, ok := s.authenticate(w, r)
	if !ok {
		return
	}
	if err := s.store.RevokeDevice(r.Context(), auth.Workspace.ID, r.PathValue("id"), s.now()); err != nil {
		s.storeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "revoked"})
}

func (s *Server) pushSync(w http.ResponseWriter, r *http.Request) {
	auth, ok := s.authenticate(w, r)
	if !ok {
		return
	}
	var request struct {
		Events []domain.EncryptedSyncEvent `json:"events"`
	}
	if err := s.decode(w, r, &request); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if len(request.Events) < 1 || len(request.Events) > 500 {
		s.writeError(w, r, http.StatusBadRequest, "invalid_sync_batch", "Sync batches require between 1 and 500 events.")
		return
	}
	for _, event := range request.Events {
		if err := validateEvent(event, auth, s.now()); err != nil {
			s.writeError(w, r, http.StatusBadRequest, "invalid_sync_event", err.Error())
			return
		}
	}
	events, err := s.store.PushEvents(r.Context(), auth, request.Events)
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"events": events})
}

func (s *Server) pullSync(w http.ResponseWriter, r *http.Request) {
	auth, ok := s.authenticate(w, r)
	if !ok {
		return
	}
	var request struct {
		AfterSequence int64 `json:"afterSequence"`
		Limit         int   `json:"limit"`
	}
	if err := s.decode(w, r, &request); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if request.AfterSequence < 0 || request.Limit < 1 || request.Limit > 500 {
		s.writeError(w, r, http.StatusBadRequest, "invalid_sync_cursor", "The sync cursor or limit is invalid.")
		return
	}
	events, next, err := s.store.PullEvents(r.Context(), auth.Workspace.ID, request.AfterSequence, request.Limit)
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"events": events, "nextSequence": next})
}

func (s *Server) contentManifest(w http.ResponseWriter, r *http.Request) {
	auth, ok := s.authenticate(w, r)
	if !ok {
		return
	}
	manifest, err := s.store.ContentManifest(r.Context(), auth.Workspace.ID)
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	etag := `"` + manifest.Head.ManifestSHA256 + `"`
	w.Header().Set("ETag", etag)
	w.Header().Set("Cache-Control", "private, max-age=60")
	if r.Header.Get("If-None-Match") == etag {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	writeJSON(w, http.StatusOK, manifest)
}

func (s *Server) contentPackage(w http.ResponseWriter, r *http.Request) {
	auth, ok := s.authenticate(w, r)
	if !ok {
		return
	}
	pkg, err := s.store.ContentPackage(r.Context(), auth.Workspace.ID, r.PathValue("id"))
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	if authorization := pkg.Authorization; authorization != nil &&
		(authorization.ReleaseID != pkg.ReleaseID ||
			authorization.ReleaseChannel != "internal" ||
			authorization.TransportSHA256 != pkg.SHA256 ||
			authorization.TransportByteLength != pkg.ByteLength ||
			authorization.Signature != pkg.Signature) {
		s.writeError(w, r, http.StatusConflict, "content_package_metadata_invalid", "The content package metadata is inconsistent.")
		return
	}
	body, err := s.objects.Read(r.Context(), pkg.ObjectKey)
	if err != nil {
		if errors.Is(err, objectstore.ErrNotFound) {
			s.writeError(w, r, http.StatusNotFound, "content_package_missing", "The content package is unavailable.")
		} else {
			s.writeError(w, r, http.StatusBadGateway, "content_storage_unavailable", "Private content storage is unavailable.")
		}
		return
	}
	hash := sha256.Sum256(body)
	if int64(len(body)) != pkg.ByteLength || hex.EncodeToString(hash[:]) != pkg.SHA256 {
		s.writeError(w, r, http.StatusConflict, "content_package_integrity_failed", "The content package failed integrity validation.")
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Length", strconv.Itoa(len(body)))
	w.Header().Set("ETag", `"`+pkg.SHA256+`"`)
	w.Header().Set("Cache-Control", "private, immutable, max-age=31536000")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(body)
}

func (s *Server) rotateRecovery(w http.ResponseWriter, r *http.Request) {
	var request struct {
		WorkspaceID               string               `json:"workspaceId"`
		ExpectedGeneration        int                  `json:"expectedGeneration"`
		RecoveryVerifierSHA256    string               `json:"recoveryVerifierSha256"`
		NewRecoveryVerifierSHA256 string               `json:"newRecoveryVerifierSha256"`
		NewRootDevice             domain.TrustedDevice `json:"newRootDevice"`
	}
	if err := s.decode(w, r, &request); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if !idPattern.MatchString(request.WorkspaceID) || request.ExpectedGeneration < 1 || !sha256Pattern.MatchString(request.RecoveryVerifierSHA256) || !sha256Pattern.MatchString(request.NewRecoveryVerifierSHA256) {
		s.writeError(w, r, http.StatusBadRequest, "invalid_recovery_request", "The recovery request is invalid.")
		return
	}
	if err := validateDevice(request.NewRootDevice); err != nil {
		s.writeError(w, r, http.StatusBadRequest, "invalid_recovery_device", err.Error())
		return
	}
	workspace, device, err := s.store.RotateRecovery(r.Context(), domain.RecoveryInput{
		WorkspaceID:             request.WorkspaceID,
		ExpectedGeneration:      request.ExpectedGeneration,
		RecoveryVerifierSHA256:  request.RecoveryVerifierSHA256,
		NewRecoveryVerifierHash: request.NewRecoveryVerifierSHA256,
		NewRootDevice:           request.NewRootDevice,
	}, s.now())
	if err != nil {
		s.storeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"workspace": workspace, "device": device})
}

func (s *Server) authenticate(w http.ResponseWriter, r *http.Request) (domain.AuthContext, bool) {
	header := r.Header.Get("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		s.writeError(w, r, http.StatusUnauthorized, "device_token_required", "A trusted device token is required.")
		return domain.AuthContext{}, false
	}
	raw := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
	if !tokenPattern.MatchString(raw) {
		s.writeError(w, r, http.StatusUnauthorized, "invalid_device_token", "The trusted device token is invalid.")
		return domain.AuthContext{}, false
	}
	hash := sha256.Sum256([]byte(raw))
	auth, err := s.store.AuthenticateToken(r.Context(), hex.EncodeToString(hash[:]), s.now())
	if err != nil {
		s.storeError(w, r, err)
		return domain.AuthContext{}, false
	}
	return auth, true
}

func (s *Server) decode(w http.ResponseWriter, r *http.Request, target any) error {
	r.Body = http.MaxBytesReader(w, r.Body, s.cfg.MaxRequestBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			return errBodyTooLarge
		}
		return fmt.Errorf("invalid JSON request")
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return fmt.Errorf("request must contain exactly one JSON object")
	}
	return nil
}

func (s *Server) storeError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		s.writeError(w, r, http.StatusNotFound, "not_found", "The requested private resource was not found.")
	case errors.Is(err, store.ErrForbidden):
		s.writeError(w, r, http.StatusForbidden, "forbidden", "This device is not allowed to perform the request.")
	case errors.Is(err, store.ErrExpired):
		s.writeError(w, r, http.StatusGone, "expired", "The requested operation has expired.")
	case errors.Is(err, store.ErrReplay):
		s.writeError(w, r, http.StatusConflict, "replayed_device_challenge", "The device challenge was already used.")
	case errors.Is(err, store.ErrConflict), errors.Is(err, store.ErrAlreadyBootstrap):
		s.writeError(w, r, http.StatusConflict, "conflict", "The private workspace state changed.")
	default:
		s.log.Error("store operation failed", "requestId", requestID(r.Context()), "errorType", fmt.Sprintf("%T", err))
		s.writeError(w, r, http.StatusInternalServerError, "internal_error", "The private sync service could not complete the request.")
	}
}

func (s *Server) writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	writeJSON(w, status, map[string]any{
		"error": map[string]any{
			"code":      code,
			"message":   message,
			"requestId": requestID(r.Context()),
		},
	})
}

func (s *Server) requestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := opaqueID("req", 10)
		start := s.now()
		ctx := context.WithValue(r.Context(), requestIDKey{}, id)
		next.ServeHTTP(w, r.WithContext(ctx))
		s.log.Info("request complete", "requestId", id, "method", r.Method, "path", r.URL.Path, "durationMs", time.Since(start).Milliseconds())
	})
}

func (s *Server) cors(next http.Handler) http.Handler {
	allowed := map[string]bool{}
	for _, origin := range s.cfg.AllowedOrigins {
		allowed[origin] = true
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && allowed[origin] {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Headers", "authorization, content-type, if-none-match")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		}
		if r.Method == http.MethodOptions {
			if origin == "" || !allowed[origin] {
				s.writeError(w, r, http.StatusForbidden, "origin_forbidden", "This browser origin is not allowed.")
				return
			}
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) limit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		host, _, _ := net.SplitHostPort(r.RemoteAddr)
		key := host + ":" + r.URL.Path
		if !s.limits.Allow(key, s.now()) {
			w.Header().Set("Retry-After", "60")
			s.writeError(w, r, http.StatusTooManyRequests, "rate_limited", "Too many private sync requests.")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) recover(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				s.log.Error("request panic", "requestId", requestID(r.Context()), "errorType", fmt.Sprintf("%T", recovered))
				s.writeError(w, r, http.StatusInternalServerError, "internal_error", "The private sync service could not complete the request.")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func validateDevice(device domain.TrustedDevice) error {
	if !idPattern.MatchString(device.ID) || len(device.Label) < 1 || len(device.Label) > 80 || !platforms[device.Platform] {
		return errors.New("device identity, label or platform is invalid")
	}
	if _, err := decodeKey(device.SigningPublicKey, ed25519.PublicKeySize); err != nil {
		return errors.New("device signing public key is invalid")
	}
	if _, err := decodeKey(device.EncryptionPublicKey, 32); err != nil {
		return errors.New("device encryption public key is invalid")
	}
	return nil
}

func validateEvent(event domain.EncryptedSyncEvent, auth domain.AuthContext, now time.Time) error {
	if event.WorkspaceID != auth.Workspace.ID || event.DeviceID != auth.Device.ID {
		return errors.New("event ownership does not match the authenticated device")
	}
	if !idPattern.MatchString(event.ID) || !idPattern.MatchString(event.IdempotencyKey) || !streamPattern.MatchString(event.Stream) || !sha256Pattern.MatchString(event.EntityHash) {
		return errors.New("event identity or index metadata is invalid")
	}
	if !eventKinds[event.Kind] || !mergePolicies[event.MergePolicy] || event.LogicalRevision < 1 || event.KeyVersion < 1 {
		return errors.New("event kind, merge policy or revision is invalid")
	}
	if len(event.Nonce) > 128 || len(event.CipherText) < 1 || len(event.CipherText) > 4*1024*1024 || len(event.AuthenticationTag) > 128 {
		return errors.New("event encrypted payload is invalid")
	}
	if absDuration(now.Sub(event.ClientCreatedAt)) > 365*24*time.Hour {
		return errors.New("event client timestamp is outside the accepted retention window")
	}
	return nil
}

func decodeKey(value string, expected int) ([]byte, error) {
	decoded, err := decodeBase64URL(value)
	if err != nil || len(decoded) != expected {
		return nil, errors.New("invalid key")
	}
	return decoded, nil
}

func decodeBase64URL(value string) ([]byte, error) {
	if decoded, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(value, "=")); err == nil {
		return decoded, nil
	}
	return base64.URLEncoding.DecodeString(value)
}

func opaqueID(prefix string, size int) string {
	raw := make([]byte, size)
	if _, err := rand.Read(raw); err != nil {
		panic(err)
	}
	return prefix + "_" + hex.EncodeToString(raw)
}

func randomToken(size int) string {
	raw := make([]byte, size)
	if _, err := rand.Read(raw); err != nil {
		panic(err)
	}
	return base64.RawURLEncoding.EncodeToString(raw)
}

func pairingCode() string {
	raw := make([]byte, 4)
	if _, err := rand.Read(raw); err != nil {
		panic(err)
	}
	value := (uint32(raw[0])<<24 | uint32(raw[1])<<16 | uint32(raw[2])<<8 | uint32(raw[3])) % 1000000
	code := fmt.Sprintf("%06d", value)
	return code[:3] + "-" + code[3:]
}

func absDuration(value time.Duration) time.Duration {
	if value < 0 {
		return -value
	}
	return value
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

type requestIDKey struct{}

func requestID(ctx context.Context) string {
	value, _ := ctx.Value(requestIDKey{}).(string)
	return value
}

type rateLimiter struct {
	mu      sync.Mutex
	limit   int
	window  time.Duration
	buckets map[string]rateBucket
}

type rateBucket struct {
	count int
	reset time.Time
}

func newRateLimiter(limit int, window time.Duration) *rateLimiter {
	return &rateLimiter{limit: limit, window: window, buckets: map[string]rateBucket{}}
}

func (r *rateLimiter) Allow(key string, now time.Time) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	bucket := r.buckets[key]
	if bucket.reset.IsZero() || !now.Before(bucket.reset) {
		r.buckets[key] = rateBucket{count: 1, reset: now.Add(r.window)}
		return true
	}
	if bucket.count >= r.limit {
		return false
	}
	bucket.count++
	r.buckets[key] = bucket
	return true
}

package store

import (
	"context"
	"errors"
	"time"

	"synapse.local/personal-sync/internal/domain"
)

var (
	ErrNotFound         = errors.New("not found")
	ErrConflict         = errors.New("conflict")
	ErrForbidden        = errors.New("forbidden")
	ErrExpired          = errors.New("expired")
	ErrReplay           = errors.New("replay")
	ErrAlreadyBootstrap = errors.New("already bootstrapped")
)

type Store interface {
	Bootstrap(context.Context, domain.BootstrapInput) (domain.PersonalWorkspace, domain.TrustedDevice, error)
	CreatePairing(context.Context, domain.PairingSession) (domain.PairingSession, error)
	ApprovePairing(context.Context, string, string, string, string, string) (domain.PairingSession, error)
	PairingCandidate(context.Context, string, string, string) (domain.TrustedDevice, domain.PersonalWorkspace, error)
	ConsumePairing(context.Context, string, string, string) (domain.PairingSession, error)
	Device(context.Context, string) (domain.TrustedDevice, domain.PersonalWorkspace, error)
	ConsumeNonce(context.Context, string, string, time.Time) error
	SaveAccessToken(context.Context, domain.AccessToken) error
	AuthenticateToken(context.Context, string, time.Time) (domain.AuthContext, error)
	ListDevices(context.Context, string) ([]domain.TrustedDevice, error)
	RevokeDevice(context.Context, string, string, time.Time) error
	PushEvents(context.Context, domain.AuthContext, []domain.EncryptedSyncEvent) ([]domain.EncryptedSyncEvent, error)
	PullEvents(context.Context, string, int64, int) ([]domain.EncryptedSyncEvent, int64, error)
	ContentManifest(context.Context, string) (*domain.ContentManifest, error)
	ContentPackage(context.Context, string, string) (domain.SignedChapterPackage, error)
	RotateRecovery(context.Context, domain.RecoveryInput, time.Time) (domain.PersonalWorkspace, domain.TrustedDevice, error)
}

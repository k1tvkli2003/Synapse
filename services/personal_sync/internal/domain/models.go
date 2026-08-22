package domain

import "time"

type PersonalWorkspace struct {
	ID                 string    `json:"id"`
	KeyVersion         int       `json:"keyVersion"`
	RecoveryGeneration int       `json:"recoveryGeneration"`
	CreatedAt          time.Time `json:"createdAt"`
}

type TrustedDevice struct {
	ID                  string     `json:"id"`
	WorkspaceID         string     `json:"workspaceId"`
	Label               string     `json:"label"`
	Platform            string     `json:"platform"`
	Role                string     `json:"role"`
	SigningPublicKey    string     `json:"signingPublicKey"`
	EncryptionPublicKey string     `json:"encryptionPublicKey"`
	CreatedAt           time.Time  `json:"createdAt"`
	LastSeenAt          time.Time  `json:"lastSeenAt"`
	RevokedAt           *time.Time `json:"revokedAt"`
}

type PairingSession struct {
	ID                           string     `json:"id"`
	PairingCode                  string     `json:"pairingCode,omitempty"`
	WorkspaceID                  string     `json:"workspaceId,omitempty"`
	CandidateDeviceID            string     `json:"candidateDeviceId"`
	CandidateLabel               string     `json:"candidateLabel"`
	CandidatePlatform            string     `json:"candidatePlatform"`
	CandidateSigningPublicKey    string     `json:"candidateSigningPublicKey"`
	CandidateEncryptionPublicKey string     `json:"candidateEncryptionPublicKey"`
	State                        string     `json:"state"`
	CreatedAt                    time.Time  `json:"createdAt"`
	ExpiresAt                    time.Time  `json:"expiresAt"`
	ApprovedAt                   *time.Time `json:"approvedAt"`
	SealedWorkspaceKey           *string    `json:"sealedWorkspaceKey"`
}

type EncryptedSyncEvent struct {
	ID                string     `json:"id"`
	WorkspaceID       string     `json:"workspaceId"`
	DeviceID          string     `json:"deviceId"`
	Stream            string     `json:"stream"`
	EntityHash        string     `json:"entityHash"`
	Kind              string     `json:"kind"`
	MergePolicy       string     `json:"mergePolicy"`
	LogicalRevision   int        `json:"logicalRevision"`
	KeyVersion        int        `json:"keyVersion"`
	IdempotencyKey    string     `json:"idempotencyKey"`
	ClientCreatedAt   time.Time  `json:"clientCreatedAt"`
	Nonce             string     `json:"nonce"`
	CipherText        string     `json:"cipherText"`
	AuthenticationTag string     `json:"authenticationTag"`
	Tombstone         bool       `json:"tombstone"`
	ServerSequence    *int64     `json:"serverSequence,omitempty"`
	ReceivedAt        *time.Time `json:"-"`
}

type SignedChapterPackage struct {
	ID               string                       `json:"id"`
	ReleaseID        string                       `json:"releaseId"`
	CourseSourceKey  string                       `json:"courseSourceKey"`
	ChapterSourceKey string                       `json:"chapterSourceKey"`
	Ordinal          int                          `json:"ordinal"`
	ByteLength       int64                        `json:"byteLength"`
	SHA256           string                       `json:"sha256"`
	Signature        string                       `json:"signature"`
	ObjectKey        string                       `json:"objectKey"`
	Authorization    *ChapterPackageAuthorization `json:"authorization,omitempty"`
}

// ChapterPackageAuthorization is the complete detached Ed25519 envelope for
// one chapter-sized curriculum payload. The Go gateway transports it but never
// holds the publisher private key or decides its validity for the learner.
type ChapterPackageAuthorization struct {
	SchemaVersion       int    `json:"schemaVersion"`
	Domain              string `json:"domain"`
	Algorithm           string `json:"algorithm"`
	KeyID               string `json:"keyId"`
	SourceID            string `json:"sourceId"`
	ReleaseID           string `json:"releaseId"`
	ReleaseChannel      string `json:"releaseChannel"`
	CanonicalSHA256     string `json:"canonicalSha256"`
	CanonicalByteLength int64  `json:"canonicalByteLength"`
	TransportSHA256     string `json:"transportSha256"`
	TransportByteLength int64  `json:"transportByteLength"`
	// SignedAt is deliberately the exact canonical UTC string covered by the
	// detached signature. A Go time.Time JSON value may omit `.000`, while the
	// Flutter verifier correctly requires the publisher's canonical form.
	SignedAt  string `json:"signedAt"`
	Signature string `json:"signature"`
}

type PersonalChannelHead struct {
	Channel        string    `json:"channel"`
	ReleaseID      string    `json:"releaseId"`
	ManifestSHA256 string    `json:"manifestSha256"`
	Sequence       int64     `json:"sequence"`
	UpdatedAt      time.Time `json:"updatedAt"`
}

type ContentManifest struct {
	SchemaVersion int                    `json:"schemaVersion"`
	Head          PersonalChannelHead    `json:"head"`
	Packages      []SignedChapterPackage `json:"packages"`
}

type AccessToken struct {
	Hash      string
	DeviceID  string
	ExpiresAt time.Time
}

type AuthContext struct {
	Workspace PersonalWorkspace
	Device    TrustedDevice
}

type BootstrapInput struct {
	Workspace              PersonalWorkspace
	RecoveryVerifierSHA256 string
	Device                 TrustedDevice
}

type RecoveryInput struct {
	WorkspaceID             string
	ExpectedGeneration      int
	RecoveryVerifierSHA256  string
	NewRecoveryVerifierHash string
	NewRootDevice           TrustedDevice
}

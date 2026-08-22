package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port                   string
	StoreMode              string
	DatabaseURL            string
	SupabaseURL            string
	SupabaseSecretKey      string
	StorageBucket          string
	BootstrapTokenSHA256   string
	AllowedOrigins         []string
	AccessTokenTTL         time.Duration
	PairingTTL             time.Duration
	DeviceSignatureMaxSkew time.Duration
	MaxRequestBytes        int64
}

func Load() (Config, error) {
	cfg := Config{
		Port:                   value("PORT", "8080"),
		StoreMode:              strings.ToLower(value("SYNAPSE_STORE", "postgres")),
		DatabaseURL:            os.Getenv("SYNAPSE_DATABASE_URL"),
		SupabaseURL:            strings.TrimRight(os.Getenv("SUPABASE_URL"), "/"),
		SupabaseSecretKey:      os.Getenv("SUPABASE_SECRET_KEY"),
		StorageBucket:          value("SYNAPSE_STORAGE_BUCKET", "synapse-personal-content"),
		BootstrapTokenSHA256:   strings.ToLower(os.Getenv("SYNAPSE_BOOTSTRAP_TOKEN_SHA256")),
		AllowedOrigins:         splitCSV(os.Getenv("SYNAPSE_ALLOWED_ORIGINS")),
		AccessTokenTTL:         duration("SYNAPSE_ACCESS_TOKEN_TTL", 15*time.Minute),
		PairingTTL:             duration("SYNAPSE_PAIRING_TTL", 5*time.Minute),
		DeviceSignatureMaxSkew: duration("SYNAPSE_SIGNATURE_MAX_SKEW", 90*time.Second),
		MaxRequestBytes:        int64Value("SYNAPSE_MAX_REQUEST_BYTES", 3*1024*1024),
	}
	if cfg.Port == "" {
		return Config{}, errors.New("PORT must not be empty")
	}
	if len(cfg.BootstrapTokenSHA256) != 64 {
		return Config{}, errors.New("SYNAPSE_BOOTSTRAP_TOKEN_SHA256 must be lowercase SHA-256")
	}
	if cfg.StoreMode != "memory" && cfg.StoreMode != "postgres" {
		return Config{}, fmt.Errorf("unsupported SYNAPSE_STORE %q", cfg.StoreMode)
	}
	if cfg.StoreMode == "postgres" {
		if cfg.DatabaseURL == "" || cfg.SupabaseURL == "" || cfg.SupabaseSecretKey == "" {
			return Config{}, errors.New("database URL, Supabase URL and server secret are required")
		}
		if !strings.HasPrefix(cfg.SupabaseURL, "https://") {
			return Config{}, errors.New("SUPABASE_URL must use HTTPS outside memory mode")
		}
	}
	return cfg, nil
}

func value(key, fallback string) string {
	if raw := strings.TrimSpace(os.Getenv(key)); raw != "" {
		return raw
	}
	return fallback
}

func splitCSV(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	var result []string
	for _, item := range strings.Split(raw, ",") {
		if value := strings.TrimSpace(item); value != "" {
			result = append(result, value)
		}
	}
	return result
}

func duration(key string, fallback time.Duration) time.Duration {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	parsed, err := time.ParseDuration(raw)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}

func int64Value(key string, fallback int64) int64 {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	parsed, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}

package objectstore

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type Supabase struct {
	baseURL   string
	secretKey string
	bucket    string
	client    *http.Client
	maxBytes  int64
}

func NewSupabase(baseURL, secretKey, bucket string) *Supabase {
	return &Supabase{
		baseURL:   strings.TrimRight(baseURL, "/"),
		secretKey: secretKey,
		bucket:    bucket,
		client:    &http.Client{Timeout: 30 * time.Second},
		maxBytes:  64 * 1024 * 1024,
	}
}

func (s *Supabase) Read(ctx context.Context, key string) ([]byte, error) {
	path := escapePath(s.bucket) + "/" + escapePath(key)
	endpoint := s.baseURL + "/storage/v1/object/authenticated/" + path
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, fmt.Errorf("build storage request: %w", err)
	}
	request.Header.Set("Authorization", "Bearer "+s.secretKey)
	request.Header.Set("apikey", s.secretKey)
	response, err := s.client.Do(request)
	if err != nil {
		return nil, fmt.Errorf("download private object: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode == http.StatusNotFound {
		return nil, ErrNotFound
	}
	if response.StatusCode != http.StatusOK {
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 4096))
		return nil, fmt.Errorf("storage returned status %d", response.StatusCode)
	}
	reader := io.LimitReader(response.Body, s.maxBytes+1)
	body, err := io.ReadAll(reader)
	if err != nil {
		return nil, fmt.Errorf("read private object: %w", err)
	}
	if int64(len(body)) > s.maxBytes {
		return nil, fmt.Errorf("private object exceeds %d bytes", s.maxBytes)
	}
	return body, nil
}

func escapePath(value string) string {
	parts := strings.Split(strings.Trim(value, "/"), "/")
	for index, part := range parts {
		parts[index] = url.PathEscape(part)
	}
	return strings.Join(parts, "/")
}

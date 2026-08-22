package objectstore

import (
	"context"
	"errors"
)

var ErrNotFound = errors.New("object not found")

type Store interface {
	Read(context.Context, string) ([]byte, error)
}

type Memory map[string][]byte

func (m Memory) Read(_ context.Context, key string) ([]byte, error) {
	value, ok := m[key]
	if !ok {
		return nil, ErrNotFound
	}
	return append([]byte(nil), value...), nil
}

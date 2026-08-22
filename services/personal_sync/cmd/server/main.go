package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"synapse.local/personal-sync/internal/api"
	"synapse.local/personal-sync/internal/config"
	"synapse.local/personal-sync/internal/objectstore"
	"synapse.local/personal-sync/internal/store"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg, err := config.Load()
	if err != nil {
		logger.Error("invalid service configuration", "error", err.Error())
		os.Exit(1)
	}

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	var persistence store.Store
	var closeStore func()
	var objects objectstore.Store
	if cfg.StoreMode == "memory" {
		persistence = store.NewMemory()
		objects = objectstore.Memory{}
		closeStore = func() {}
	} else {
		postgres, openErr := store.OpenPostgres(ctx, cfg.DatabaseURL)
		if openErr != nil {
			logger.Error("private database is unavailable", "error", openErr.Error())
			os.Exit(1)
		}
		persistence = postgres
		objects = objectstore.NewSupabase(cfg.SupabaseURL, cfg.SupabaseSecretKey, cfg.StorageBucket)
		closeStore = postgres.Close
	}
	defer closeStore()

	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           api.New(cfg, persistence, objects, logger).Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       20 * time.Second,
		WriteTimeout:      65 * time.Second,
		IdleTimeout:       90 * time.Second,
	}
	errCh := make(chan error, 1)
	go func() { errCh <- server.ListenAndServe() }()

	select {
	case signalErr := <-errCh:
		if !errors.Is(signalErr, http.ErrServerClosed) {
			logger.Error("private sync gateway stopped", "error", signalErr.Error())
			os.Exit(1)
		}
	case <-ctx.Done():
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer shutdownCancel()
		if shutdownErr := server.Shutdown(shutdownCtx); shutdownErr != nil {
			logger.Error("private sync gateway shutdown failed", "error", shutdownErr.Error())
		}
	}
}

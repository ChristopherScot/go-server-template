package main

import (
	"fmt"
	"log/slog"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func healthz(w http.ResponseWriter, _ *http.Request) {
	fmt.Fprintln(w, "ok")
}

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Get("/healthz", healthz)
	r.Get("/", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "hello")
	})

	// Configurable so the service can run alongside others locally; the
	// deploy manifest sets it explicitly.
	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}
	slog.Info("started", "addr", ":"+port)
	if err := http.ListenAndServe("0.0.0.0:"+port, r); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

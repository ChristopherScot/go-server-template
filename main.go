package main

import (
	"log/slog"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("welcome team"))
		logger.ErrorContext(r.Context(), "This isn't a real error",
			"key1", "value1",
			"key2", "value2",
		)
	})
	slog.Info("Server started at :3000")
	http.ListenAndServe("0.0.0.0:3000", r)
}

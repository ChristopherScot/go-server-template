package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// A trivial test so `go test -race ./...` in CI has something to run and
// "this repo has tests" is the default rather than something to set up.
func TestHealthz(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	healthz(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("healthz status = %d, want %d", w.Code, http.StatusOK)
	}
}

package main

import (
	"log"
	"net/http"
)

type healthzHandler struct{}

func (h *healthzHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("content-type", "application/json")

	if usingRedis {
		if _, err := dbLink.Do("PING"); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			if _, writeErr := w.Write([]byte(`{"status":"unavailable","redis":"down"}`)); writeErr != nil {
				log.Println("healthz: failed to write response:", writeErr)
			}
			return
		}
	}

	w.WriteHeader(http.StatusOK)
	if _, err := w.Write([]byte(`{"status":"ok"}`)); err != nil {
		log.Println("healthz: failed to write response:", err)
	}
}

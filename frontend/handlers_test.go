package main

import (
	"bytes"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeClient struct {
	err  error
	resp *http.Response
}

func (f *fakeClient) Get(url string) (*http.Response, error) {
	return f.resp, f.err
}

func (f *fakeClient) Post(url, contentType string, body io.Reader) (*http.Response, error) {
	return f.resp, f.err
}

func TestRandomHandler_BackendDown(t *testing.T) {
	myClient = &fakeClient{err: errors.New("connection refused")}

	req := httptest.NewRequest(http.MethodGet, "/api/random", nil)
	w := httptest.NewRecorder()
	RandomHandler(w, req)

	if w.Code != http.StatusBadGateway {
		t.Errorf("expected status 502, got %d", w.Code)
	}
}

func TestAllHandler_BackendDown(t *testing.T) {
	myClient = &fakeClient{err: errors.New("connection refused")}

	req := httptest.NewRequest(http.MethodGet, "/api/all", nil)
	w := httptest.NewRecorder()
	AllHandler(w, req)

	if w.Code != http.StatusBadGateway {
		t.Errorf("expected status 502, got %d", w.Code)
	}
}

func TestAddHandler_BackendDown(t *testing.T) {
	myClient = &fakeClient{err: errors.New("connection refused")}

	body := bytes.NewBufferString(`{"message":"test"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/add", body)
	w := httptest.NewRecorder()
	AddHandler(w, req)

	if w.Code != http.StatusBadGateway {
		t.Errorf("expected status 502, got %d", w.Code)
	}
}

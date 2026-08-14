package main

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gomodule/redigo/redis"
)

type fakeRedisConn struct {
	pingErr error
}

func (f *fakeRedisConn) Close() error { return nil }
func (f *fakeRedisConn) Err() error   { return nil }
func (f *fakeRedisConn) Do(commandName string, args ...interface{}) (interface{}, error) {
	if commandName == "PING" {
		return nil, f.pingErr
	}
	return nil, nil
}
func (f *fakeRedisConn) Send(commandName string, args ...interface{}) error { return nil }
func (f *fakeRedisConn) Flush() error                                       { return nil }
func (f *fakeRedisConn) Receive() (interface{}, error)                      { return nil, nil }

func newFakePool(pingErr error) *redis.Pool {
	return &redis.Pool{
		MaxIdle:   1,
		MaxActive: 1,
		Dial: func() (redis.Conn, error) {
			return &fakeRedisConn{pingErr: pingErr}, nil
		},
	}
}

func TestHealthz_NoRedisConfigured(t *testing.T) {
	usingRedis = false

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	(&healthzHandler{}).ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
}

func TestHealthz_RedisUp(t *testing.T) {
	usingRedis = true
	dbPool = newFakePool(nil)

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	(&healthzHandler{}).ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
}

func TestHealthz_RedisDown(t *testing.T) {
	usingRedis = true
	dbPool = newFakePool(errors.New("connection refused"))

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	(&healthzHandler{}).ServeHTTP(w, req)

	if w.Code != http.StatusServiceUnavailable {
		t.Errorf("expected status 503, got %d", w.Code)
	}
}
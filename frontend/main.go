package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"math/rand"
	"net/http"
	"time"
)

var BACKEND_DNS = getEnv("BACKEND_DNS", "localhost")
var BACKEND_PORT = getEnv("BACKEND_PORT", "9000")

type fortune struct {
	ID      string `json:"id" redis:"id"`
	Message string `json:"message" redis:"message"`
}

type newFortune struct {
	Message string `json:"message"`
}

type httpClient interface {
	Get(url string) (*http.Response, error)
	Post(url, contentType string, body io.Reader) (*http.Response, error)
}

// use a custom client, because we don't do blocking operations wihout timeouts
var myClient httpClient = &http.Client{Timeout: 10 * time.Second}

func HealthzHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	io.WriteString(w, "healthy")
}

func RandomHandler(w http.ResponseWriter, r *http.Request) {
	resp, err := myClient.Get(fmt.Sprintf("http://%s:%s/fortunes/random", BACKEND_DNS, BACKEND_PORT))
	if err != nil {
		http.Error(w, "fortune service unavailable", http.StatusBadGateway)
		return
	}

	f := new(fortune)
	json.NewDecoder(resp.Body).Decode(f)

	fmt.Fprint(w, f.Message)
}

func AllHandler(w http.ResponseWriter, r *http.Request) {
	resp, err := myClient.Get(fmt.Sprintf("http://%s:%s/fortunes", BACKEND_DNS, BACKEND_PORT))
	if err != nil {
		http.Error(w, "fortune service unavailable", http.StatusBadGateway)
		return
	}

	fortunes := new([]fortune)
	json.NewDecoder(resp.Body).Decode(fortunes)

	tmpl, err := template.ParseFiles("./templates/fortunes.html")
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	tmpl.Execute(w, fortunes)
}

func AddHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Use POST", http.StatusMethodNotAllowed)
		return
	}

	f := new(newFortune)
	json.NewDecoder(r.Body).Decode(f)

	postUrl := fmt.Sprintf("http://%s:%s/fortunes", BACKEND_DNS, BACKEND_PORT)
	jsonStr := []byte(fmt.Sprintf(`{"id": "%d", "message": "%s"}`, rand.Intn(10000), f.Message))

	_, err := myClient.Post(postUrl, "application/json", bytes.NewBuffer(jsonStr))
	if err != nil {
		http.Error(w, "fortune service unavailable", http.StatusBadGateway)
		return
	}

	fmt.Fprint(w, "Cookie added!")
}

func main() {
	http.HandleFunc("/healthz", HealthzHandler)
	http.HandleFunc("/api/random", RandomHandler)
	http.HandleFunc("/api/all", AllHandler)
	http.HandleFunc("/api/add", AddHandler)
	http.Handle("/", http.FileServer(http.Dir("./static")))

	err := http.ListenAndServe(":8080", nil)
	fmt.Printf("%v", err)
}
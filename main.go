package main

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

type speechRequest struct {
	Model          string   `json:"model"`
	Input          string   `json:"input"`
	Voice          string   `json:"voice"`
	ResponseFormat string   `json:"response_format"`
	Speed          *float64 `json:"speed,omitempty"`
	Pitch          *float64 `json:"pitch,omitempty"`
	Volume         *int     `json:"volume,omitempty"`
	SampleRate     *int     `json:"sample_rate,omitempty"`
}

type wsHeader struct {
	Action       string `json:"action"`
	TaskID       string `json:"task_id"`
	Streaming    string `json:"streaming"`
	Event        string `json:"event,omitempty"`
	ErrorMessage string `json:"error_message,omitempty"`
	RequestID    string `json:"request_id,omitempty"`
}

type wsPayload struct {
	Input      map[string]any `json:"input"`
	Parameters map[string]any `json:"parameters,omitempty"`
	TaskGroup  string         `json:"task_group,omitempty"`
	Task       string         `json:"task,omitempty"`
	Function   string         `json:"function,omitempty"`
	Model      string         `json:"model,omitempty"`
}

type wsEnvelope struct {
	Header  wsHeader  `json:"header"`
	Payload wsPayload `json:"payload,omitempty"`
}

type modelsResponse struct {
	Object string       `json:"object"`
	Data   []modelEntry `json:"data"`
}

type modelEntry struct {
	ID     string `json:"id"`
	Object string `json:"object"`
	Owned  string `json:"owned_by"`
}

func main() {
	addr := flag.String("addr", ":8090", "listen address")
	flag.Parse()

	if envPort := strings.TrimSpace(os.Getenv("PORT")); envPort != "" {
		if !strings.HasPrefix(envPort, ":") {
			envPort = ":" + envPort
		}
		*addr = envPort
	}

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	http.HandleFunc("/v1/models", handleModels)
	http.HandleFunc("/v1/audio/speech", handleSpeech)

	log.Printf("[oneapi-bridge] listening on %s", *addr)
	if err := http.ListenAndServe(*addr, nil); err != nil {
		log.Fatal(err)
	}
}

func handleModels(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	resp := modelsResponse{
		Object: "list",
		Data: []modelEntry{
			{ID: "cosyvoice-v3-flash", Object: "model", Owned: "openclaw"},
		},
	}
	buf, _ := json.Marshal(resp)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(buf)
}

func handleSpeech(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	apiKey := strings.TrimSpace(os.Getenv("DASHSCOPE_API_KEY"))
	if apiKey == "" {
		http.Error(w, "missing DASHSCOPE_API_KEY", http.StatusInternalServerError)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "failed to read body", http.StatusBadRequest)
		return
	}
	_ = r.Body.Close()

	req, err := decodeSpeechRequest(body)
	if err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}

	if strings.TrimSpace(req.Input) == "" {
		http.Error(w, "input is required", http.StatusBadRequest)
		return
	}

	model := strings.TrimSpace(req.Model)
	if model == "" {
		model = "cosyvoice-v3-flash"
	}
	voice := strings.TrimSpace(req.Voice)
	if voice == "" {
		voice = "longanyang"
	}
	voice = mapVoice(voice)
	format := normalizeResponseFormat(req.ResponseFormat)
	if format != "mp3" && format != "wav" {
		log.Printf("[tts] unsupported response_format=%s", req.ResponseFormat)
		http.Error(w, "unsupported response_format (supported: mp3, wav)", http.StatusBadRequest)
		return
	}

	sampleRate := 22050
	if req.SampleRate != nil && *req.SampleRate > 0 {
		sampleRate = *req.SampleRate
	}

	volume := 50
	if req.Volume != nil && *req.Volume > 0 {
		volume = *req.Volume
	}

	rate := 1.0
	if req.Speed != nil && *req.Speed > 0 {
		rate = *req.Speed
	}

	pitch := 1.0
	if req.Pitch != nil && *req.Pitch > 0 {
		pitch = *req.Pitch
	}

	wsURL := strings.TrimSpace(os.Getenv("DASHSCOPE_WS_URL"))
	if wsURL == "" {
		wsURL = "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
	}
	deadline := 60 * time.Second
	if v := strings.TrimSpace(os.Getenv("DASHSCOPE_TIMEOUT")); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			deadline = d
		}
	}

	log.Printf("[tts] model=%s voice=%s format=%s sample_rate=%d rate=%.2f pitch=%.2f response_format=%s", model, voice, format, sampleRate, rate, pitch, strings.TrimSpace(req.ResponseFormat))

	audio, err := callCosyVoice(wsURL, apiKey, model, voice, format, sampleRate, volume, rate, pitch, req.Input, deadline)
	if err != nil {
		log.Printf("[tts] cosyvoice error: %v", err)
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}

	if format == "mp3" {
		w.Header().Set("Content-Type", "audio/mpeg")
	} else {
		w.Header().Set("Content-Type", "audio/wav")
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(audio)
}

func decodeSpeechRequest(body []byte) (speechRequest, error) {
	var raw map[string]any
	if err := json.Unmarshal(body, &raw); err != nil {
		return speechRequest{}, err
	}
	req := speechRequest{
		Model:          getString(raw, "model"),
		Input:          getString(raw, "input", "text"),
		Voice:          getString(raw, "voice", "speaker", "spk"),
		ResponseFormat: getString(raw, "response_format", "format", "audio_format"),
	}
	if v, ok := getFloatPtr(raw, "speed", "rate"); ok {
		req.Speed = v
	}
	if v, ok := getFloatPtr(raw, "pitch"); ok {
		req.Pitch = v
	}
	if v, ok := getIntPtr(raw, "volume", "vol"); ok {
		req.Volume = v
	}
	if v, ok := getIntPtr(raw, "sample_rate", "sampleRate", "sample_rate_hz"); ok {
		req.SampleRate = v
	}
	return req, nil
}

func getString(m map[string]any, keys ...string) string {
	for _, key := range keys {
		val, ok := m[key]
		if !ok || val == nil {
			continue
		}
		switch v := val.(type) {
		case string:
			if strings.TrimSpace(v) != "" {
				return v
			}
		case json.Number:
			return v.String()
		case float64:
			return strconv.FormatFloat(v, 'f', -1, 64)
		case int:
			return strconv.Itoa(v)
		case int64:
			return strconv.FormatInt(v, 10)
		case bool:
			if v {
				return "true"
			}
			return "false"
		}
	}
	return ""
}

func getFloatPtr(m map[string]any, keys ...string) (*float64, bool) {
	for _, key := range keys {
		val, ok := m[key]
		if !ok || val == nil {
			continue
		}
		switch v := val.(type) {
		case float64:
			return &v, true
		case int:
			f := float64(v)
			return &f, true
		case int64:
			f := float64(v)
			return &f, true
		case json.Number:
			if f, err := v.Float64(); err == nil {
				return &f, true
			}
		case string:
			if f, err := strconv.ParseFloat(strings.TrimSpace(v), 64); err == nil {
				return &f, true
			}
		}
	}
	return nil, false
}

func getIntPtr(m map[string]any, keys ...string) (*int, bool) {
	for _, key := range keys {
		val, ok := m[key]
		if !ok || val == nil {
			continue
		}
		switch v := val.(type) {
		case float64:
			i := int(v)
			return &i, true
		case int:
			return &v, true
		case int64:
			i := int(v)
			return &i, true
		case json.Number:
			if i64, err := v.Int64(); err == nil {
				i := int(i64)
				return &i, true
			}
		case string:
			if i64, err := strconv.ParseInt(strings.TrimSpace(v), 10, 64); err == nil {
				i := int(i64)
				return &i, true
			}
		}
	}
	return nil, false
}

func normalizeResponseFormat(input string) string {
	format := strings.ToLower(strings.TrimSpace(input))
	if format == "" {
		return "mp3"
	}
	// Map common OpenAI formats to CosyVoice supported formats
	switch format {
	case "opus", "ogg", "ogg_opus":
		return "mp3"
	case "pcm", "wav":
		return "wav"
	case "mp3":
		return "mp3"
	}
	return format
}

func mapVoice(voice string) string {
	voice = strings.TrimSpace(strings.ToLower(voice))
	if voice == "" {
		return "longanyang"
	}
	// Map OpenAI-style voices to a default CosyVoice voice
	switch voice {
	case "alloy", "echo", "fable", "onyx", "nova", "shimmer":
		return "longanyang"
	}
	return voice
}

func callCosyVoice(wsURL, apiKey, model, voice, format string, sampleRate, volume int, rate, pitch float64, text string, deadline time.Duration) ([]byte, error) {
	header := http.Header{}
	header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))

	dialer := websocket.Dialer{HandshakeTimeout: 15 * time.Second}
	conn, _, err := dialer.Dial(wsURL, header)
	if err != nil {
		return nil, fmt.Errorf("dial websocket failed: %w", err)
	}
	defer conn.Close()

	_ = conn.SetReadDeadline(time.Now().Add(deadline))

	taskID := newTaskID()
	run := wsEnvelope{
		Header: wsHeader{
			Action:    "run-task",
			TaskID:    taskID,
			Streaming: "duplex",
		},
		Payload: wsPayload{
			TaskGroup: "audio",
			Task:      "tts",
			Function:  "SpeechSynthesizer",
			Model:     model,
			Input:     map[string]any{},
			Parameters: map[string]any{
				"text_type":   "PlainText",
				"voice":       voice,
				"format":      format,
				"sample_rate": sampleRate,
				"volume":      volume,
				"rate":        rate,
				"pitch":       pitch,
			},
		},
	}

	if err := conn.WriteJSON(run); err != nil {
		return nil, fmt.Errorf("send run-task failed: %w", err)
	}

	var audio bytes.Buffer
	sentText := false
	for {
		mt, msg, err := conn.ReadMessage()
		if err != nil {
			return nil, fmt.Errorf("read websocket failed: %w", err)
		}
		switch mt {
		case websocket.BinaryMessage:
			_, _ = audio.Write(msg)
		case websocket.TextMessage:
			var resp wsEnvelope
			if err := json.Unmarshal(msg, &resp); err != nil {
				continue
			}
			event := strings.ToLower(resp.Header.Event)
			switch event {
			case "task-failed":
				if resp.Header.ErrorMessage != "" {
					return nil, errors.New(resp.Header.ErrorMessage)
				}
				return nil, errors.New("cosyvoice task failed")
			case "task-started":
				if !sentText {
					cont := wsEnvelope{
						Header:  wsHeader{Action: "continue-task", TaskID: taskID, Streaming: "duplex"},
						Payload: wsPayload{Input: map[string]any{"text": text}},
					}
					if err := conn.WriteJSON(cont); err != nil {
						return nil, fmt.Errorf("send continue-task failed: %w", err)
					}
					finish := wsEnvelope{
						Header:  wsHeader{Action: "finish-task", TaskID: taskID, Streaming: "duplex"},
						Payload: wsPayload{Input: map[string]any{}},
					}
					if err := conn.WriteJSON(finish); err != nil {
						return nil, fmt.Errorf("send finish-task failed: %w", err)
					}
					sentText = true
				}
			case "task-finished":
				return audio.Bytes(), nil
			}
		}
	}
}

func newTaskID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

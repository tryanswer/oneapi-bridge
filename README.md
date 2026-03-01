# openclaw_bridge

A tiny HTTP bridge that exposes `/v1/audio/speech` (OpenAI-compatible TTS) and calls Aliyun DashScope CosyVoice over WebSocket.

## Requirements

- Go 1.22+
- `DASHSCOPE_API_KEY`

## Run

```bash
export DASHSCOPE_API_KEY=sk-xxx
# Optional: DASHSCOPE_WS_URL=wss://dashscope.aliyuncs.com/api-ws/v1/inference
# Optional: DASHSCOPE_TIMEOUT=60s

go run . -addr :8090
```

## Test

```bash
curl -sS http://127.0.0.1:8090/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d model:cosyvoice-v3-flash \
  -o output.mp3
```

## OneAPI channel setup

- Channel type: OpenAI Compatible / Custom Proxy
- Base URL: `http://127.0.0.1:8090`
- Models: `cosyvoice-v3-flash`

Then call OneAPI `/v1/audio/speech` with `model=cosyvoice-v3-flash`.


Scripts
- scripts/install.sh: install deps and build
- scripts/start.sh: start in background (PORT env supported, default 8090)
- scripts/stop.sh: stop background process
- scripts/status.sh: process status
- scripts/health.sh: health check (/healthz)
- scripts/service_install.sh: install system service (systemd or launchd)
- scripts/service_uninstall.sh: remove service
- scripts/service_start.sh: start service
- scripts/service_stop.sh: stop service
- scripts/service_status.sh: service status

Parameter mapping
- model: model
- input: input or text
- voice: voice or speaker or spk
- response_format: response_format or format or audio_format
- speed: speed or rate
- pitch: pitch
- volume: volume or vol
- sample_rate: sample_rate or sampleRate or sample_rate_hz

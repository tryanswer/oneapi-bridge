# oneapi_bridge

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
- scripts/start.sh: start service if installed, otherwise run in background (PORT env supported, default 8090)
- scripts/stop.sh: stop service if installed, otherwise stop background process
- scripts/status.sh: show service status if installed, otherwise process status
- scripts/health.sh: health check (/healthz)

Parameter mapping
- model: model
- input: input or text
- voice: voice or speaker or spk
- response_format: response_format or format or audio_format
- speed: speed or rate
- pitch: pitch
- volume: volume or vol
- sample_rate: sample_rate or sampleRate or sample_rate_hz

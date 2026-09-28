# Local LLM Stack — Mac Mini (MLX-native)

Self-hosted chat stack for Apple Silicon Macs: **llama-swap** hot-swaps quantized MLX models on demand → **LiteLLM** exposes them behind one unified OpenAI-compatible gateway → **Open WebUI** provides the chat interface, with file upload/RAG for PDF, Excel, CSV, and images.

Runs comfortably on a 16GB Mac Mini with Qwen3.5-4B and Gemma-4-E4B.

## Architecture
Open WebUI (:8080, chat + file upload/RAG) [Docker]
-> LiteLLM (:4000, unified gateway, friendly names) [Docker]
-> llama-swap (:8000, loads/unloads on demand) [native]
-> mlx_lm.server (dynamic port) [native]
-> Qwen3.5-4B OR Gemma-4-E4B (never both loaded at once)

**Why llama-swap/MLX run natively instead of in Docker:** Docker Desktop on macOS runs containers inside a Linux VM with no access to Apple's Metal/GPU, so containerizing the MLX inference layer would mean losing the acceleration that makes this stack fast. LiteLLM, Open WebUI, and Docling don't need the GPU, so those run in Docker for easy setup/updates.

## Prerequisites

- Apple Silicon Mac (M1 or newer), 16GB+ RAM recommended
- [Homebrew](https://brew.sh)
- Docker Desktop for Mac

## Setup

### 1. Native MLX layer

```bash
xcode-select --install
brew install uv
uv tool install mlx-lm

brew tap mostlygeek/llama-swap
brew trust --formula mostlygeek/llama-swap/llama-swap
brew install llama-swap

cp llama-swap/config.example.yaml llama-swap/config.yaml
./scripts/start-llama-swap.sh
```

Leave that running. In another terminal, verify:

```bash
curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"mlx-community/Qwen3.5-4B-MLX-4bit","messages":[{"role":"user","content":"hi"}]}'
```

(First call is slow — it's downloading + loading the model.)

### 2. Containerized layer

```bash
cp .env.example .env        # edit LITELLM_MASTER_KEY to your own value
cp litellm/config.example.yaml litellm/config.yaml
docker compose up -d
```

### 3. Open WebUI

Visit `http://localhost:8080`, create your local admin account, then go to **Settings → Admin → Connections → Manage OpenAI API Connections → +**:
- Base URL: `http://litellm:4000` *(already wired via docker-compose; no action needed unless you changed ports)*
- API key: whatever you set as `LITELLM_MASTER_KEY`

Both `qwen3.5-4b` and `gemma4-e4b` should appear in the model picker.

### 4. File upload / RAG

CSV/TXT/MD work out of the box (bundled ChromaDB + local embedding model). For PDF/Excel table-aware parsing, Docling is already running via docker-compose — set **Settings → Admin → Documents** extraction engine to Docling, server URL `http://docling:5001`.

## RAM budget (16GB Mac)

| Scenario | RAM used |
|---|---|
| Base (macOS + containers + llama-swap idle) | ~5.3 GB |
| + Qwen3.5-4B resident | ~8.8 GB |
| + Gemma-4-E4B resident (worst case in normal use) | ~11.8 GB |

## Model substitution note

Neither "Qwen3.8" nor "Gemma 4" ships a dense 4B model as of writing (Qwen3.8 starts at 27B; Gemma 4 ships E2B/E4B/12B/26B-A4B/31B, no dense 4B). This repo uses the closest "latest, ~4B-class" pairing that actually exists: `mlx-community/Qwen3.5-4B-MLX-4bit` and `mlx-community/gemma-4-e4b-it-4bit`. Swap the repo ids in both config files to use different models.

## Troubleshooting

- **`Refusing to load formula ... untrusted tap`** — Homebrew 6.0+ requires `brew trust --formula mostlygeek/llama-swap/llama-swap` before installing from a third-party tap.
- **`no model id could be identified`** — the request needs an explicit `Content-Type: application/json` header, or llama-swap can't parse the body.
- **`Repository Not Found` from mlx_lm.server** — `mlx_lm.server` treats the request's `"model"` field as an optional HF repo override. The model name in `llama-swap/config.yaml` must be the *exact* HF repo id, not a short alias — friendly names live one layer up, in LiteLLM's config.
- **LiteLLM container can't reach llama-swap** — confirm llama-swap is listening on `0.0.0.0:8000` (see `scripts/start-llama-swap.sh`), not `127.0.0.1:8000` — the latter isn't reachable from inside a container.

## License

MIT — see [LICENSE](LICENSE).

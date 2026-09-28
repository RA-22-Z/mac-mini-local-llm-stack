#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
llama-swap --config "$DIR/llama-swap/config.yaml" --listen 0.0.0.0:8000

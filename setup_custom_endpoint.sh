#!/usr/bin/env bash
# setup_custom_endpoint.sh — deterministic Hermes CLI + Desktop custom endpoint setup
# Replicable by humans & machines. Idempotent (safe to re-run).
#
# Usage:
#   ./setup_custom_endpoint.sh --base-url <URL> --api-key <KEY> --model <MODEL> [--name <NAME>]
#
# Example:
#   ./setup_custom_endpoint.sh \
#     --base-url "https://gateway.example.com/v1" \
#     --api-key "sk-xxxx" \
#     --model "myorg/my-model" \
#     --name "my-gateway"

set -euo pipefail

# ── Parse args ──────────────────────────────────────────────────────────────
BASE_URL=""
API_KEY=""
MODEL=""
NAME="custom-endpoint"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) BASE_URL="$2"; shift 2 ;;
    --api-key)  API_KEY="$2";  shift 2 ;;
    --model)    MODEL="$2";    shift 2 ;;
    --name)     NAME="$2";     shift 2 ;;
    -h|--help)
      echo "Usage: $0 --base-url <URL> --api-key <KEY> --model <MODEL> [--name <NAME>]"
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$BASE_URL" || -z "$API_KEY" || -z "$MODEL" ]]; then
  echo "ERROR: --base-url, --api-key, --model are required" >&2
  exit 1
fi

# ── 0. Hermes installed? ─────────────────────────────────────────────────────
if ! command -v hermes >/dev/null 2>&1; then
  echo "Installing Hermes..."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
fi
hermes --version >/dev/null 2>&1 || { echo "ERROR: hermes not available" >&2; exit 1; }

echo "=== [1/4] Configure model (CLI + Desktop shared config) ==="
hermes config set model.provider custom
hermes config set model.base_url "$BASE_URL"
hermes config set model.api_key "$API_KEY"
hermes config set model.default "$MODEL"
hermes config set model.api_mode chat_completions

echo "=== [2/4] Register named custom provider ==="
hermes config set custom_providers.0.name "$NAME"
hermes config set custom_providers.0.base_url "$BASE_URL"
hermes config set custom_providers.0.api_key "$API_KEY"
hermes config set custom_providers.0.model "$MODEL"
hermes config set custom_providers.0.api_mode chat_completions
hermes config set custom_providers.0.models.0 "$MODEL"

echo "=== [3/4] Live endpoint test (real API call) ==="
HTTP_CODE=$(curl -s -o /tmp/hermes_endpoint_test.json -w "%{http_code}" \
  "$BASE_URL/chat/completions" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":5}")
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "WARNING: endpoint returned HTTP $HTTP_CODE (see /tmp/hermes_endpoint_test.json)" >&2
  echo "         config written anyway — fix endpoint, then re-run." >&2
else
  echo "OK: endpoint responded 200"
fi

echo "=== [4/4] Hermes self-test (CLI talks to endpoint) ==="
OUT=$(hermes chat -q "Reply with exactly: CONNECTED" 2>&1 || true)
if echo "$OUT" | grep -q "CONNECTED"; then
  echo "OK: hermes chat connected via custom endpoint"
else
  echo "WARNING: hermes self-test did not echo CONNECTED" >&2
  echo "         output was: $OUT" >&2
  echo "         config written — check model name & endpoint." >&2
fi

echo ""
echo "✅ DONE. Config written to ~/.hermes/config.yaml"
echo "   Launch Desktop:  hermes desktop"
echo "   Desktop auto-uses this config (same file)."
echo "   Verify again anytime:  ./verify_custom_endpoint.sh"

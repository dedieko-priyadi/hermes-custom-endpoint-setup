#!/usr/bin/env bash
# verify_custom_endpoint.sh — deterministic verification of Hermes custom endpoint setup
# Exit 0 = all checks pass. Non-zero = something wrong (with which check).
#
# Usage: ./verify_custom_endpoint.sh [--base-url <URL>] [--model <MODEL>] [--api-key <KEY>]
# If args omitted, values are read from the live config.

set -uo pipefail

FAIL=0

echo "═══ [1/4] Config check ═══"
PROVIDER=$(hermes config get model.provider 2>/dev/null || echo "?")
BASE_URL=$(hermes config get model.base_url 2>/dev/null || echo "?")
MODEL=$(hermes config get model.default 2>/dev/null || echo "?")
echo "  provider : $PROVIDER"
echo "  base_url : $BASE_URL"
echo "  model    : $MODEL"
if [[ "$PROVIDER" != "custom" ]]; then echo "  ❌ provider != custom"; FAIL=1; else echo "  ✅ provider=custom"; fi
if [[ "$BASE_URL" == "?" || -z "$BASE_URL" ]]; then echo "  ❌ base_url empty"; FAIL=1; else echo "  ✅ base_url set"; fi
if [[ "$MODEL" == "?" || -z "$MODEL" ]]; then echo "  ❌ model empty"; FAIL=1; else echo "  ✅ model set"; fi

# CLI arg overrides
[[ -n "${1:-}" && "$1" == "--base-url" ]] && BASE_URL="$2"
[[ -n "${1:-}" && "$1" == "--model" ]] && MODEL="$2"

echo "═══ [2/4] Endpoint live test ═══"
API_KEY=$(hermes config get model.api_key 2>/dev/null || echo "")
HTTP_CODE=$(curl -s -o /tmp/hermes_verify.json -w "%{http_code}" \
  "$BASE_URL/chat/completions" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":5}" 2>/dev/null)
echo "  HTTP $HTTP_CODE"
if [[ "$HTTP_CODE" == "200" ]]; then echo "  ✅ endpoint reachable"; else echo "  ❌ endpoint failed"; FAIL=1; fi

echo "═══ [3/4] Hermes self-test ═══"
OUT=$(hermes chat -q "Reply with exactly: CONNECTED" 2>&1 || true)
if echo "$OUT" | grep -q "CONNECTED"; then echo "  ✅ CLI connected"; else echo "  ❌ CLI failed: ${OUT:0:120}"; FAIL=1; fi

echo "═══ [4/4] Desktop config presence ═══"
if [[ -f "$HOME/.hermes/config.yaml" ]]; then echo "  ✅ config.yaml exists (Desktop reads it)"; else echo "  ❌ config.yaml missing"; FAIL=1; fi

echo ""
if [[ "$FAIL" == "0" ]]; then
  echo "✅ ALL CHECKS PASSED — CLI + Desktop are connected to $BASE_URL"
  exit 0
else
  echo "❌ $FAIL check(s) failed — see above. Re-run setup_custom_endpoint.sh."
  exit 1
fi

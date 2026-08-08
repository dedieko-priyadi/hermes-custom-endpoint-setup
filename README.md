# Hermes Custom Endpoint Setup

Deterministic guide to configure **Hermes Agent** (CLI + Desktop) to use a **custom LLM endpoint** (OpenAI-compatible base URL, e.g. a self-hosted gateway like 9router, vLLM, Ollama, LiteLLM, or any provider with an OpenAI-compatible API).

**Goal**: friends install Hermes CLI → run one script → CLI is connected to the custom endpoint → **Hermes Desktop auto-inherits the same configuration** (no manual desktop setup).

This guide is **replicable by both humans and machines**. A friend can simply ask their Hermes CLI to read this repository.

---

## How it works (1 minute mental model)

Hermes uses a single shared configuration file for ALL surfaces (CLI, Desktop, Gateway, Dashboard):

```
~/.hermes/config.yaml   ← ONE file, all surfaces read it
```

- **CLI** reads `model.provider`, `model.base_url`, `model.api_key` from `config.yaml`
- **Desktop** (`hermes desktop`) is an Electron wrapper around the same Hermes core — it reads the **same** `~/.hermes/config.yaml`
- Therefore: **configure the CLI once → Desktop works automatically. No separate desktop setup.**

The setup is done with the official `hermes config set` commands (never hand-edit YAML).

---

## Prerequisites

- **Linux / macOS / WSL**: `curl`, bash
- **Windows**: PowerShell 5.1+ (built-in)
- A custom endpoint that speaks **OpenAI-compatible Chat Completions** (`POST {base_url}/chat/completions`)
- An API key for that endpoint (or none, if the endpoint is open)

> **Windows + WSL**: if your friend prefers WSL, use the bash scripts — identical behavior.

---

## Setup Steps (deterministic)

### 0. Install Hermes (if not installed)

**Linux / macOS / WSL:**
```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
# verify
hermes --version
```

**Windows (PowerShell):**
```powershell
irm https://hermes-agent.nousresearch.com/install.ps1 | iex
# verify (reopen terminal first if hermes not found)
hermes --version
```

### 1. Run the setup script

**Linux / macOS / WSL (bash):**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dedieko-priyadi/hermes-custom-endpoint-setup/main/setup_custom_endpoint.sh)" \
  --base-url "https://your-gateway.example.com/v1" \
  --api-key "sk-your-key" \
  --model "your/model-name" \
  --name "my-gateway"
```

**Windows (PowerShell):**

```powershell
# download script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dedieko-priyadi/hermes-custom-endpoint-setup/main/setup_custom_endpoint.ps1" -OutFile setup_custom_endpoint.ps1

# run (bypass execution policy for this script)
powershell -ExecutionPolicy Bypass -File .\setup_custom_endpoint.ps1 `
  -BaseUrl "https://your-gateway.example.com/v1" `
  -ApiKey "sk-your-key" `
  -Model "your/model-name" `
  -Name "my-gateway"
```

> **Windows note**: If PowerShell blocks the script, run `Set-ExecutionPolicy -Scope Process Bypass` first, or right-click the file → "Run with PowerShell".

### 2. What the script does (deterministic, idempotent)

| Step | Command | Effect |
|---|---|---|
| 1 | `hermes config set model.provider custom` | Switch provider to `custom` |
| 2 | `hermes config set model.base_url <URL>` | Point at your endpoint |
| 3 | `hermes config set model.api_key <KEY>` | Set the API key |
| 4 | `hermes config set model.default <MODEL>` | Set default model |
| 5 | `hermes config set model.api_mode chat_completions` | OpenAI-compatible mode |
| 6 | `hermes config set custom_providers.0.name <NAME>` | Register named provider |
| 7 | `hermes config set custom_providers.0.base_url <URL>` | Provider base URL |
| 8 | `hermes config set custom_providers.0.api_key <KEY>` | Provider key |
| 9 | `hermes config set custom_providers.0.model <MODEL>` | Provider default model |
| 10 | `hermes config set custom_providers.0.api_mode chat_completions` | Provider mode |
| 11 | `hermes config set custom_providers.0.models.<i> <MODEL>` | Register models list |

All steps are idempotent — re-running is safe.

### 3. Verify (deterministic)

**All platforms:**

```bash
# 1. Config check
hermes config get model.provider        # → custom
hermes config get model.base_url        # → your URL
hermes config get model.default         # → your model

# 2. Live connectivity test (real API call, not just config)
curl -s $BASE_URL/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"'"$MODEL"'","messages":[{"role":"user","content":"ping"}],"max_tokens":5}'
# expect: {"id":"...","choices":[{"message":{"content":"..."}}]}

# 3. Hermes self-test (this is the REAL proof — CLI itself talks to the endpoint)
hermes chat -q "Reply with exactly: CONNECTED"
# expect output: CONNECTED
```

**Windows PowerShell** (steps 2 & 3 — Invoke-RestMethod + same hermes command):
```powershell
Invoke-RestMethod -Uri "$BASE_URL/chat/completions" -Method Post `
  -Headers @{ Authorization = "Bearer $API_KEY" } -ContentType "application/json" `
  -Body (@{ model = "$MODEL"; messages = @(@{ role = "user"; content = "ping" }); max_tokens = 5 } | ConvertTo-Json -Depth 5)
hermes chat -q "Reply with exactly: CONNECTED"
```

Or run the bundled verification scripts:
```bash
# Linux/macOS/WSL
./verify_custom_endpoint.sh

# Windows
powershell -ExecutionPolicy Bypass -File .\verify_custom_endpoint.ps1
```

### 4. Launch Desktop

```bash
hermes desktop    # alias: hermes gui
```

**Desktop reads the same config — it is already connected.** No desktop-specific setting exists or is needed.

---

## Verification checklist (both human & machine)

- [ ] `hermes config get model.provider` = `custom`
- [ ] `hermes config get model.base_url` = your endpoint
- [ ] `hermes config get model.default` = your model
- [ ] `curl` to `/chat/completions` returns 200 + JSON with `choices`
- [ ] `hermes chat -q "Reply with exactly: CONNECTED"` → `CONNECTED`
- [ ] `hermes desktop` opens and the model selector shows your model
- [ ] Desktop chat works (send a message, get a reply)

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `hermes chat` → connection error | wrong base_url / network blocked | `hermes config set model.base_url <URL>`; test with curl first |
| 401 Unauthorized | wrong/expired API key | `hermes config set model.api_key <KEY>` |
| 404 model not found | model name doesn't exist on endpoint | list models: `curl $BASE_URL/models`; fix `model.default` |
| Desktop shows default provider | `model.provider` not `custom` | re-run script (step 1) |
| **CLI doesn't match Desktop selection** | user picked a different provider in Desktop vs CLI (same config file) | `hermes setup model` — re-run the provider wizard in CLI, then verify `hermes config get model.provider` |
| `hermes desktop` won't start | desktop deps missing | `hermes doctor` |
| **Gateway still uses old provider** | running gateway process cached old config | `hermes gateway restart` (from a separate shell) |

**Force re-run the provider setup wizard (interactive):**

```bash
hermes setup model        # wizard: pick provider + model + API key
hermes model              # alternative interactive picker
hermes model --refresh    # wipe model cache, re-fetch live /v1/models
hermes setup --reset      # reset config to defaults (clean slate)
```

**Reload summary**: CLI & Desktop auto-reload config on every new process. Only a **running gateway** (Telegram/WhatsApp/Discord) needs a manual restart: `hermes gateway restart`.

---

## Files

```
hermes-custom-endpoint-setup/
├── README.md                        ← this guide (Linux + Windows)
├── SKILL.md                         ← Hermes skill — friend's CLI can load this directly
├── setup_custom_endpoint.sh         ← deterministic setup script (bash)
├── verify_custom_endpoint.sh        ← deterministic verification script (bash)
├── setup_custom_endpoint.ps1        ← deterministic setup script (Windows PowerShell)
└── verify_custom_endpoint.ps1       ← deterministic verification script (Windows PowerShell)
```

## For your Hermes CLI (friend)

Tell your Hermes: **"Read https://github.com/dedieko-priyadi/hermes-custom-endpoint-setup — load SKILL.md and follow it."** The skill contains the full deterministic flow (install → setup → verify → desktop).

## Maintainer

Dedi Eko Yunanto Priyadi — BTD UGM (dedieko@ugm.ac.id)

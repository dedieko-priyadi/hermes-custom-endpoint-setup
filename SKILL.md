---
name: hermes-custom-endpoint-setup
description: "Configure Hermes CLI + Desktop to use a custom OpenAI-compatible endpoint. Deterministic setup for friends (Linux/Windows). Use when user wants to connect Hermes to a custom LLM gateway (9router, vLLM, Ollama, LiteLLM)."
version: 1.0.0
platforms: [linux, macos, windows]
---

# Hermes Custom Endpoint Setup

Guide utk menyambungkan Hermes (CLI + Desktop) ke **custom OpenAI-compatible endpoint**. Deterministic — bisa dijalankan sistem maupun manusia.

## Konsep Kunci

**Satu config utk SEMUA surface**: `~/.hermes/config.yaml` dibaca CLI, Desktop (`hermes desktop`), Gateway, Dashboard.

**Setup CLI sekali → Desktop auto-inherit.** TIDAK ada setting terpisah utk Desktop.

## Prasyarat

- Hermes terinstall (lihat step 0)
- Endpoint OpenAI-compatible: `POST {base_url}/chat/completions`
- API key endpoint (atau open endpoint)

## Alur (deterministic, idempotent)

### Step 0 — Install Hermes

**Linux/macOS/WSL**:
```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
hermes --version
```

**Windows PowerShell**:
```powershell
irm https://hermes-agent.nousresearch.com/install.ps1 | iex
hermes --version
```

### Step 1 — Jalankan script setup

**Linux/macOS/WSL (bash)** — ambil dari git publik:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dedieko-priyadi/hermes-custom-endpoint-setup/main/setup_custom_endpoint.sh)" \
  --base-url "https://gateway.example.com/v1" \
  --api-key "sk-xxx" \
  --model "org/model" \
  --name "my-gateway"
```

**Windows (PowerShell)**:
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dedieko-priyadi/hermes-custom-endpoint-setup/main/setup_custom_endpoint.ps1" -OutFile setup.ps1
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -BaseUrl "https://gateway.example.com/v1" -ApiKey "sk-xxx" -Model "org/model" -Name "my-gateway"
```

### Step 2 — Apa yang script lakukan (11 config set)

```bash
hermes config set model.provider custom
hermes config set model.base_url "$BASE_URL"
hermes config set model.api_key "$API_KEY"
hermes config set model.default "$MODEL"
hermes config set model.api_mode chat_completions
hermes config set custom_providers.0.name "$NAME"
hermes config set custom_providers.0.base_url "$BASE_URL"
hermes config set custom_providers.0.api_key "$API_KEY"
hermes config set custom_providers.0.model "$MODEL"
hermes config set custom_providers.0.api_mode chat_completions
hermes config set custom_providers.0.models.0 "$MODEL"
```

Semua idempotent — re-run aman. **JANGAN hand-edit config.yaml** — selalu `hermes config set`.

### Step 3 — Verify (wajib, bukti bukan klaim)

**Config di-reload otomatis**: CLI baca `config.yaml` fresh di SETIAP proses baru — `hermes chat` baru = provider baru. Tidak ada cache persisten di CLI. (Satu-satunya yang perlu restart adalah **gateway** yang sedang berjalan: `hermes gateway restart` — lihat bawah.)

```bash
# config check
hermes config get model.provider   # → custom
hermes config get model.base_url  # → URL endpoint
hermes config get model.default   # → model

# validasi config (deteksi opsi outdated/missing)
hermes config check

# refresh katalog model/provider (setelah tambah custom_providers)
hermes model --refresh

# live endpoint test (real API call)
curl -s "$BASE_URL/chat/completions" \
  -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"'"$MODEL"'","messages":[{"role":"user","content":"ping"}],"max_tokens":5}'

# hermes self-test (bukti paling kuat)
hermes chat -q "Reply with exactly: CONNECTED"   # → CONNECTED
```

Atau script verify:
```bash
./verify_custom_endpoint.sh          # Linux
powershell -ExecutionPolicy Bypass -File .\verify_custom_endpoint.ps1   # Windows
```

### Step 4 — Desktop

```bash
hermes desktop    # alias: hermes gui
```
Desktop baca config yang sama — sudah connect, tanpa setting tambahan.

## Troubleshooting

| Gejala | Penyebab | Fix |
|---|---|---|
| connection error | base_url salah / network | cek curl dulu; `hermes config set model.base_url` |
| 401 | key salah/expired | `hermes config set model.api_key` |
| 404 model not found | nama model salah | `curl $BASE_URL/models`; fix `model.default` |
| Desktop pakai provider default | `model.provider` ≠ custom | re-run script |
| **Gateway/Telegram masih pakai provider lama** | gateway proses berjalan baca config lama | `hermes gateway restart` (dari shell terpisah) |

**Ringkasan reload**: CLI & Desktop = auto-reload tiap proses baru. Hanya **gateway** (layanan berjalan: Telegram/WhatsApp/Discord) yang perlu restart manual: `hermes gateway restart`.

## Referensi Repo

- **Git**: https://github.com/dedieko-priyadi/hermes-custom-endpoint-setup
- File: `README.md` (panduan lengkap), `setup_custom_endpoint.{sh,ps1}`, `verify_custom_endpoint.{sh,ps1}`

## Pitfalls

- **Satu config utk semua surface** — jangan cari setting Desktop terpisah (tidak ada)
- **Windows**: PowerShell ExecutionPolicy — pakai `-ExecutionPolicy Bypass` atau `Set-ExecutionPolicy -Scope Process Bypass`
- **.ps1 belum di-test di Windows sungguhan** (2026-08-08) — syntax PowerShell standar, verifikasi di mesin Windows bila perlu
- **Jangan hand-edit config.yaml** — `hermes config set` saja (stray indent = config korup, gateway mati)

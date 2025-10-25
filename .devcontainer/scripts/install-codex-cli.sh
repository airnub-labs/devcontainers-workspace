#!/usr/bin/env bash
set -euo pipefail

if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

log() {
  echo "[install-codex-cli] $*"
}

if command -v codex >/dev/null 2>&1; then
  log "Codex CLI already installed; skipping."
  exit 0
fi

if ! command -v pnpm >/dev/null 2>&1; then
  log "pnpm is required to install the Codex CLI; skipping installation." >&2
  exit 0
fi

codex_log="$(mktemp)"
trap 'rm -f "$codex_log"' EXIT

if pnpm install -g @openai/codex >"$codex_log" 2>&1; then
  log "Codex CLI installation complete."
else
  log "Codex CLI installation failed; continuing without it."
  log "Details: $(tail -n 20 "$codex_log" 2>/dev/null || echo 'see installer output')"
  exit 0
fi

#!/usr/bin/env bash
set -euo pipefail

if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

log() {
  echo "[install-gemini-cli] $*"
}

if command -v gemini >/dev/null 2>&1; then
  log "Gemini CLI already installed; skipping."
  exit 0
fi

if ! command -v pnpm >/dev/null 2>&1; then
  log "pnpm is required to install the Gemini CLI; skipping installation." >&2
  exit 0
fi

gemini_log="$(mktemp)"
trap 'rm -f "$gemini_log"' EXIT

if pnpm install -g @google/gemini-cli >"$gemini_log" 2>&1; then
  log "Gemini CLI installation complete."
else
  log "Gemini CLI installation failed; continuing without it."
  log "Details: $(tail -n 20 "$gemini_log" 2>/dev/null || echo 'see installer output')"
  exit 0
fi

#!/usr/bin/env bash
set -euo pipefail

if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

log() {
  echo "[install-claude-cli] $*"
}

if command -v claude >/dev/null 2>&1; then
  log "Claude CLI already installed; skipping."
  exit 0
fi

if ! command -v pnpm >/dev/null 2>&1; then
  log "pnpm is required to install the Claude CLI; skipping installation." >&2
  exit 0
fi

claude_log="$(mktemp)"
trap 'rm -f "$claude_log"' EXIT

if pnpm install -g @anthropic-ai/claude-code >"$claude_log" 2>&1; then
  log "Claude CLI installation complete."
else
  log "Claude CLI installation failed; continuing without it."
  log "Details: $(tail -n 20 "$claude_log" 2>/dev/null || echo 'see installer output')"
  exit 0
fi

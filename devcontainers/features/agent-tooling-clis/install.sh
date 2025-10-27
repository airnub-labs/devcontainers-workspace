#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[agent-tooling-clis] $*"
}

should_enable() {
  local value="${1:-}"
  case "${value,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_shim() {
  local binary="$1"
  local package="$2"
  local target="/usr/local/bin/$binary"

  if [[ -x "$target" && "$(head -n1 "$target" 2>/dev/null)" == "#!/usr/bin/env bash" ]] && grep -q "npx" "$target" 2>/dev/null; then
    return 0
  fi

  local package_escaped
  printf -v package_escaped '%q' "$package"
  cat <<EOF >"$target"
#!/usr/bin/env bash
set -euo pipefail
exec npx --yes $package_escaped "\$@"
EOF
  chmod +x "$target"
}

install_with_npm() {
  local package="$1"
  if ! command -v npm >/dev/null 2>&1; then
    return 1
  fi
  npm install -g "$package"
}

install_cli() {
  local binary="$1"
  local package="$2"
  local label="$3"

  if command -v "$binary" >/dev/null 2>&1; then
    log "$label already installed; skipping."
    return 0
  fi

  local log_file="/tmp/${binary}-install.log"

  if install_with_npm "$package" >"$log_file" 2>&1; then
    rm -f "$log_file"
    log "$label installation complete."
    return 0
  fi

  log "npm not available or installation failed for $label; providing npx shim instead."
  [[ -f "$log_file" ]] && log "Details: $(tail -n 20 "$log_file" 2>/dev/null || echo 'see $log_file')"
  ensure_shim "$binary" "$package"
}

INSTALL_CODEX="${INSTALLCODEX:-false}"
INSTALL_CLAUDE="${INSTALLCLAUDE:-false}"
INSTALL_GEMINI="${INSTALLGEMINI:-false}"

if should_enable "$INSTALL_CODEX"; then
  install_cli "codex" "@openai/codex" "Codex CLI"
else
  log "Codex CLI disabled via feature options."
fi

if should_enable "$INSTALL_CLAUDE"; then
  install_cli "claude" "@anthropic-ai/claude-code" "Claude CLI"
else
  log "Claude CLI disabled via feature options."
fi

if should_enable "$INSTALL_GEMINI"; then
  install_cli "gemini" "@google/gemini-cli" "Gemini CLI"
else
  log "Gemini CLI disabled via feature options."
fi


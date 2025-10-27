#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! ROOT="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)"; then
  ROOT="$(cd "$HERE/.." && pwd)"
fi

LOG_DIR="${DEVCONTAINER_LOG_DIR:-/var/log/devcontainer}"
LOG_FILE="${DEVCONTAINER_LOG_FILE:-$LOG_DIR/devcontainer.log}"
mkdir -p "$LOG_DIR" 2>/dev/null || true
: > "$LOG_FILE" 2>/dev/null || true

log() {
  local message="[post-create] $*"
  echo "$message"
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "$message" >>"$LOG_FILE" 2>/dev/null || true
  fi
}

# sudo is not guaranteed in containers; guard its use
SUDO=""
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

append_shell_snippet() {
  local file="$1"; local marker="$2"; local snippet="$3"
  [[ -e "$file" ]] || touch "$file" 2>/dev/null || true
  if [[ -w "$file" ]] && ! grep -Fq "$marker" "$file" 2>/dev/null; then
    {
      printf '\n'; printf '# %s\n' "$marker"; printf '%s\n' "$snippet";
    } >>"$file"
  fi
}

persist_path_prefix() {
  local target_path="$1"; local marker="$2"; local file
  local -a shell_files=( "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.zprofile" "$HOME/.zshrc" )
  for file in "${shell_files[@]}"; do
    append_shell_snippet "$file" "$marker" "export PATH=\"$target_path:\$PATH\""
  done
}

persist_env_var() {
  local var_name="$1"; local value="$2"; local marker="$3"; local file
  local -a shell_files=( "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.zprofile" "$HOME/.zshrc" )
  for file in "${shell_files[@]}"; do
    append_shell_snippet "$file" "$marker" "export $var_name=\"$value\""
  done
}

# -----------------------------
# pnpm bootstrap (user-level)
# -----------------------------

determine_pnpm_version() {
  if [[ -n "${PNPM_VERSION:-}" ]]; then echo "$PNPM_VERSION"; return 0; fi
  if [[ -f "$ROOT/package.json" && -x "$(command -v node || true)" ]]; then
    local from_package
    from_package="$(node -p "(() => { try { const pkg = require('$ROOT/package.json'); return pkg.packageManager || ''; } catch { return ''; } })()" 2>/dev/null || true)"
    if [[ "$from_package" == pnpm@* ]]; then echo "${from_package#pnpm@}"; return 0; fi
  fi
  echo "10.17.1"
}

ensure_pnpm() {
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
  mkdir -p "$PNPM_HOME"
  case ":$PATH:" in *":$PNPM_HOME:"*) ;; *) export PATH="$PNPM_HOME:$PATH" ;; esac
  if ! command -v pnpm >/dev/null 2>&1; then
    if ! command -v corepack >/dev/null 2>&1; then
      log "ERROR: corepack not found. Install Node with Corepack enabled."
      exit 1
    fi
    corepack enable || true
    local want_pnpm; want_pnpm="$(determine_pnpm_version)"
    log "Preparing pnpm@${want_pnpm} via corepack (non-interactive)..."
    corepack prepare "pnpm@${want_pnpm}" --activate
  fi
  pnpm config set global-bin-dir "$PNPM_HOME" >/dev/null 2>&1 || true
}

log "Ensuring pnpm is available and configured..."
ensure_pnpm

# -----------------------------
# Safe PNPM store configuration (user-level; persists across shells)
# -----------------------------
STORE="${PNPM_STORE_PATH:-"$HOME/.pnpm-store"}"
log "Configuring pnpm store at: $STORE"
mkdir -p "$STORE"
if [[ -n "$SUDO" ]]; then $SUDO chown -R "$(id -u)":"$(id -g)" "$STORE" || true; fi
pnpm config set store-dir "$STORE" >/dev/null 2>&1 || true
if [[ -d "/workspaces/.pnpm-store" ]]; then
  log "Removing legacy /workspaces/.pnpm-store to avoid mount-related link issues..."
  rm -rf /workspaces/.pnpm-store || true
fi

# -----------------------------
# Install workspace deps (uses safe store)
# -----------------------------
if [[ -f "$ROOT/package.json" ]]; then
  log "Installing workspace dependencies with pnpm (store: $STORE)..."
  (cd "$ROOT" && pnpm install --store-dir="$STORE")
else
  log "No package.json found; skipping pnpm install."
fi

# -----------------------------
# Tool CLIs (user-level, toggleable via dedicated scripts)
# -----------------------------
log "Installing Deno CLI...";     "$HERE/install-deno-cli.sh"
if command -v supabase >/dev/null 2>&1; then
  log "Supabase CLI provided by features; skipping manual install."
fi
if command -v codex >/dev/null 2>&1; then
  log "Codex CLI provided by features; skipping manual install."
fi
if command -v gemini >/dev/null 2>&1; then
  log "Gemini CLI provided by features; skipping manual install."
fi
if command -v claude >/dev/null 2>&1; then
  log "Claude CLI provided by features; skipping manual install."
fi

# Ensure pnpm global bin is on PATH for future shells
if [[ -n "${PNPM_HOME:-}" && -d "$PNPM_HOME" ]]; then
  case ":$PATH:" in *":$PNPM_HOME:"*) ;; *) export PATH="$PNPM_HOME:$PATH" ;; esac
  persist_env_var "PNPM_HOME" "$PNPM_HOME" "Added by devcontainer post-create to configure pnpm home"
  persist_path_prefix "$PNPM_HOME" "Added by devcontainer post-create to expose pnpm global binaries"
fi

# Ensure local Python user bin directory is on PATH for current and future shells
python_user_bin="${PIP_USER_BIN:-$HOME/.local/bin}"
if [[ -d "$python_user_bin" ]]; then
  case ":$PATH:" in *":$python_user_bin:"*) ;; *) export PATH="$python_user_bin:$PATH" ;; esac
  persist_path_prefix "$python_user_bin" "Added by devcontainer post-create to expose Python user base binaries"
fi

# Ensure the airnub CLI is directly available on PATH (symlink)
ensure_airnub_cli_on_path() {
  local cli_path="$ROOT/airnub"; local dest_dir="$HOME/.local/bin"; local dest="$dest_dir/airnub"
  if [[ ! -x "$cli_path" ]]; then log "airnub CLI not found at $cli_path; skipping PATH symlink."; return 0; fi
  mkdir -p "$dest_dir"
  if [[ -L "$dest" ]]; then
    local current_target; current_target="$(readlink "$dest" || true)"
    if [[ "$current_target" == "$cli_path" ]]; then log "airnub CLI already linked at $dest."; return 0; fi
  elif [[ -e "$dest" ]]; then
    log "A different executable already exists at $dest; leaving it in place."; return 0
  fi
  ln -sfn "$cli_path" "$dest"; log "airnub CLI linked at $dest and available on PATH."
}
ensure_airnub_cli_on_path

# -----------------------------
# Clone additional repos declared in devcontainer.json (non-fatal)
# -----------------------------
if [[ -x "$HERE/clone-from-devcontainer-repos.sh" ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    log "WARNING: jq not found (expected via image). Clone step may fail."
  fi
  log "Cloning repositories declared in devcontainer.json..."
  ALLOW_WILDCARD=0 WORKSPACE_ROOT="$ROOT" bash "$HERE/clone-from-devcontainer-repos.sh" \
    || log "Clone step skipped or failed (non-fatal)"
else
  log "clone-from-devcontainer-repos.sh not found; skipping clone step"
fi

# Warm the npx cache for the MCP servers (non-fatal)
( npx -y chrome-devtools-mcp@latest --help >/dev/null 2>&1 || true )
( npx --yes @playwright/mcp@latest --version >/dev/null 2>&1 || true )

# Configure MCP servers per client (project-scoped)
if command -v claude >/dev/null 2>&1; then
  log "Configuring Claude MCP servers via CLI (project scope)..."
  CLAUDE_CHROME_SERVER_JSON="$(python3 - <<'PYTHON'
import json, os
print(json.dumps({
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "chrome-devtools-mcp@latest", "--browserUrl", os.environ.get("CHROME_CDP_URL", "http://127.0.0.1:9222")]
}))
PYTHON
  )"
  claude mcp add-json chrome-devtools "${CLAUDE_CHROME_SERVER_JSON}" \
    || log "Claude MCP configuration skipped or already present."
fi

if command -v codex >/dev/null 2>&1; then
  log "Configuring Codex MCP servers via CLI (project scope)..."
  codex mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --browserUrl "${CHROME_CDP_URL:-http://127.0.0.1:9222}" \
    || log "Codex MCP configuration skipped or already present."
fi

log "post-create complete."

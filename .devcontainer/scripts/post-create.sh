#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! ROOT="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)"; then
  ROOT="$(cd "$HERE/.." && pwd)"
fi

log() { echo "[post-create] $*"; }

# -----------------------------
# pnpm bootstrap (unchanged)
# -----------------------------

determine_pnpm_version() {
  if [[ -n "${PNPM_VERSION:-}" ]]; then
    echo "$PNPM_VERSION"
    return 0
  fi

  if [[ -f "$ROOT/package.json" && -x "$(command -v node || true)" ]]; then
    local from_package
    from_package="$(node -p "(() => { try { const pkg = require('$ROOT/package.json'); return pkg.packageManager || ''; } catch { return ''; } })()" 2>/dev/null || true)"
    if [[ "$from_package" == pnpm@* ]]; then
      echo "${from_package#pnpm@}"
      return 0
    fi
  fi

  echo "10.17.1"
}

ensure_pnpm() {
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
  mkdir -p "$PNPM_HOME"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac

  if ! command -v pnpm >/dev/null 2>&1; then
    if ! command -v corepack >/dev/null 2>&1; then
      log "ERROR: corepack not found. Install Node with Corepack enabled."
      exit 1
    fi

    corepack enable || true
    local want_pnpm
    want_pnpm="$(determine_pnpm_version)"
    log "Preparing pnpm@${want_pnpm} via corepack (non-interactive)..."
    corepack prepare "pnpm@${want_pnpm}" --activate
  fi

  pnpm config set global-bin-dir "$PNPM_HOME" >/dev/null 2>&1 || true
}

log "Ensuring pnpm is available and configured..."
ensure_pnpm

# -----------------------------
# NEW: Safe PNPM store configuration (works in Dev Containers & Codespaces)
# -----------------------------
# Use a container-local store (default: $HOME/.pnpm-store) or respect PNPM_STORE_PATH if provided.
STORE="${PNPM_STORE_PATH:-"$HOME/.pnpm-store"}"
log "Configuring pnpm store at: $STORE"

# Create and ensure ownership (covers named volumes that default to root-owned)
mkdir -p "$STORE"
if command -v sudo >/dev/null 2>&1; then
  sudo chown -R "$(id -u)":"$(id -g)" "$STORE" || true
fi

# Persist the store path so future pnpm runs use it by default
pnpm config set store-dir "$STORE" >/dev/null 2>&1 || true

# Best-effort cleanup if a legacy store exists on the bind mount
if [[ -d "/workspaces/.pnpm-store" ]]; then
  log "Removing legacy /workspaces/.pnpm-store to avoid mount-related copy/link issues..."
  rm -rf /workspaces/.pnpm-store || true
fi

# -----------------------------
# Install workspace deps (uses safe store)
# -----------------------------
if [[ -f "$ROOT/package.json" ]]; then
  log "Installing workspace dependencies with pnpm (using store: $STORE)..."
  (cd "$ROOT" && pnpm install --store-dir="$STORE")
else
  log "No package.json found; skipping pnpm install."
fi

# -----------------------------
# Supabase CLI install (unchanged)
# -----------------------------
log "Installing Supabase CLI..."
"$HERE/install-supabase-cli.sh"

# -----------------------------
# Deno CLI install
# -----------------------------
if ! command -v deno >/dev/null 2>&1; then
  log "Installing Deno CLI..."
  deno_install_root="${DENO_INSTALL_ROOT:-$HOME/.deno}"
  deno_installer="$(mktemp)"
  if curl -fsSL https://deno.land/install.sh -o "$deno_installer"; then
    chmod +x "$deno_installer" || true
    if ! (DENO_INSTALL="$deno_install_root" \
          DENO_INSTALL_SKIP_PATH=1 \
          sh "$deno_installer" >/tmp/deno-install.log 2>&1); then
      log "Deno install script failed; continuing without ensuring Deno is available."
      log "Details: $(tail -n 20 /tmp/deno-install.log 2>/dev/null || echo 'see installer output')"
    else
      rm -f /tmp/deno-install.log
      # Ensure the current environment can see the freshly installed binary.
      case ":$PATH:" in
        *":$deno_install_root/bin:"*) ;;
        *) export PATH="$deno_install_root/bin:$PATH" ;;
      esac
      # Persist PATH updates for future shells when possible.
      shell_profile="$HOME/.profile"
      if [[ ! -e "$shell_profile" ]]; then
        touch "$shell_profile" 2>/dev/null || true
      fi
      if [[ -w "$shell_profile" ]] && ! grep -Fq "$deno_install_root/bin" "$shell_profile" 2>/dev/null; then
        {
          echo ""
          echo "# Added by devcontainer post-create to expose Deno"
          echo "export PATH=\"$deno_install_root/bin:\$PATH\""
        } >> "$shell_profile"
      fi
    fi
  else
    log "Failed to download Deno install script; skipping automatic Deno installation."
  fi
  rm -f /tmp/deno-install.log
  rm -f "$deno_installer"
else
  log "Deno CLI already installed; skipping."
fi

# -----------------------------
# Gemini CLI install
# -----------------------------
if ! command -v gemini >/dev/null 2>&1; then
  if command -v npm >/dev/null 2>&1; then
    log "Installing Gemini CLI via npm..."
    gemini_log="$(mktemp)"
    if ! npm install -g @google/gemini-cli >"$gemini_log" 2>&1; then
      log "Gemini CLI install failed; continuing without it."
      log "Details: $(tail -n 20 "$gemini_log" 2>/dev/null || echo 'see installer output')"
    else
      log "Gemini CLI installation complete."
    fi
    rm -f "$gemini_log"
  else
    log "npm not available; skipping Gemini CLI installation."
  fi
else
  log "Gemini CLI already installed; skipping."
fi

# Ensure npm global bin directory is on PATH for future shells
if command -v npm >/dev/null 2>&1; then
  npm_prefix="$(npm config get prefix 2>/dev/null | tail -n 1)"
  if [[ -z "$npm_prefix" ]]; then
    npm_prefix="$HOME/.npm-global"
  fi
  npm_bin="$npm_prefix/bin"
  if [[ -d "$npm_bin" ]]; then
    case ":$PATH:" in
      *":$npm_bin:"*) ;;
      *) export PATH="$npm_bin:$PATH" ;;
    esac
    shell_profile="$HOME/.profile"
    if [[ ! -e "$shell_profile" ]]; then
      touch "$shell_profile" 2>/dev/null || true
    fi
    if [[ -w "$shell_profile" ]] && ! grep -Fq "$npm_bin" "$shell_profile" 2>/dev/null; then
      {
        echo ""
        echo "# Added by devcontainer post-create to expose npm global binaries"
        echo "export PATH=\"$npm_bin:\$PATH\""
      } >> "$shell_profile"
    fi
  fi
fi

# -----------------------------
# Codex CLI install
# -----------------------------
if ! command -v codex >/dev/null 2>&1; then
  if command -v python3 >/dev/null 2>&1; then
    log "Installing Codex CLI via pip..."
    codex_log="$(mktemp)"
    if ! python3 -m pip install --user --upgrade codex-cli >"$codex_log" 2>&1; then
      log "Codex CLI install failed; continuing without it."
      log "Details: $(tail -n 20 "$codex_log" 2>/dev/null || echo 'see installer output')"
    else
      log "Codex CLI installation complete."
    fi
    rm -f "$codex_log"
  else
    log "python3 not available; skipping Codex CLI installation."
  fi
else
  log "Codex CLI already installed; skipping."
fi

# Ensure local Python user bin directory is on PATH for current and future shells
python_user_bin="${PIP_USER_BIN:-$HOME/.local/bin}"
if [[ -d "$python_user_bin" ]]; then
  case ":$PATH:" in
    *":$python_user_bin:"*) ;;
    *) export PATH="$python_user_bin:$PATH" ;;
  esac
  shell_profile="$HOME/.profile"
  if [[ ! -e "$shell_profile" ]]; then
    touch "$shell_profile" 2>/dev/null || true
  fi
  if [[ -w "$shell_profile" ]] && ! grep -Fq "$python_user_bin" "$shell_profile" 2>/dev/null; then
    {
      echo ""
      echo "# Added by devcontainer post-create to expose Python user base binaries"
      echo "export PATH=\"$python_user_bin:\$PATH\""
    } >> "$shell_profile"
  fi
fi

# -----------------------------
# Clone additional repos declared in devcontainer.json.
# Non-fatal if missing.
# -----------------------------
if [[ -x "$HERE/clone-from-devcontainer-repos.sh" ]]; then
  # Ensure jq for JSON parsing if available via apt-get
  if ! command -v jq >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      log "jq not found; installing via apt-get..."
      apt-get update -y && apt-get install -y jq || log "jq install failed; clone step may fail"
    else
      log "jq not found and apt-get unavailable; clone step may fail"
    fi
  fi

  log "Cloning repositories declared in devcontainer.json..."
  ALLOW_WILDCARD=0 \
  WORKSPACE_ROOT="$ROOT" \
  bash "$HERE/clone-from-devcontainer-repos.sh" || log "Clone step skipped or failed (non-fatal)"
else
  log "clone-from-devcontainer-repos.sh not found; skipping clone step"
fi

log "post-create complete."

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
ensure_in_path() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$dir:$PATH" ;;
  esac
  export PATH
}

ensure_profile_path_snippet() {
  local profile_snippet="/etc/profile.d/deno.sh"
  if [[ -w "$profile_snippet" || (! -e "$profile_snippet" && -w "/etc/profile.d") ]]; then
    cat <<'EOF' >"$profile_snippet"
if [ -d "$HOME/.deno/bin" ] && [[ ":$PATH:" != *":$HOME/.deno/bin:"* ]]; then
  export PATH="$HOME/.deno/bin:$PATH"
fi
EOF
  else
    local profile_file
    local snippet_id="Added by post-create Deno installer"
    for profile_file in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
      if [[ -e "$profile_file" && ! -w "$profile_file" ]]; then
        continue
      fi
      if [[ ! -e "$profile_file" ]]; then
        touch "$profile_file" 2>/dev/null || continue
      fi
      if ! grep -Fq "$snippet_id" "$profile_file" 2>/dev/null; then
        cat <<'EOF' >>"$profile_file"

# Added by post-create Deno installer
if [[ ":$PATH:" != *":$HOME/.deno/bin:"* ]]; then
  export PATH="$HOME/.deno/bin:$PATH"
fi
EOF
      fi
      break
    done
  fi
}

install_deno() {
  local os arch triple url tmpdir archive target_dir binary_path

  if command -v deno >/dev/null 2>&1; then
    log "Deno CLI already installed; skipping."
    ensure_in_path "$HOME/.deno/bin"
    return 0
  fi

  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Linux)
      case "$arch" in
        x86_64|amd64) triple="x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) triple="aarch64-unknown-linux-gnu" ;;
        *)
          log "Unsupported architecture for Deno: $arch"
          return 0
          ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        x86_64|amd64) triple="x86_64-apple-darwin" ;;
        arm64) triple="aarch64-apple-darwin" ;;
        *)
          log "Unsupported architecture for Deno: $arch"
          return 0
          ;;
      esac
      ;;
    *)
      log "Unsupported operating system for Deno: $os"
      return 0
      ;;
  esac

  target_dir="$HOME/.deno/bin"
  mkdir -p "$target_dir"

  tmpdir="$(mktemp -d)"
  archive="$tmpdir/deno.zip"

  if [[ -n "${DENO_VERSION:-}" ]]; then
    url="https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/deno-${triple}.zip"
  else
    url="https://github.com/denoland/deno/releases/latest/download/deno-${triple}.zip"
  fi

  log "Installing Deno CLI from ${url}..."

  if ! curl -fsSL "$url" -o "$archive"; then
    log "Failed to download Deno archive from ${url}; skipping automatic Deno installation."
    rm -rf "$tmpdir"
    return 0
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      log "unzip not found; installing via apt-get..."
      apt-get update -y && apt-get install -y unzip || log "Failed to install unzip; Deno installation may fail."
    else
      log "unzip not found and apt-get unavailable; cannot extract Deno archive."
      rm -rf "$tmpdir"
      return 0
    fi
  fi

  if ! unzip -oq "$archive" -d "$tmpdir"; then
    log "Failed to extract Deno archive; skipping installation."
    rm -rf "$tmpdir"
    return 0
  fi

  binary_path="$tmpdir/deno"
  if [[ ! -f "$binary_path" ]]; then
    log "Deno binary not found in archive; skipping installation."
    rm -rf "$tmpdir"
    return 0
  fi

  install -m 0755 "$binary_path" "$target_dir/deno"
  rm -rf "$tmpdir"

  ensure_in_path "$target_dir"
  ensure_profile_path_snippet
  log "Deno CLI installed to $target_dir/deno."
}

install_deno

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

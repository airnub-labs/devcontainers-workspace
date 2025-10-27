#!/usr/bin/env bash
set -euo pipefail

if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

log() {
  echo "[install-deno-cli] $*"
}

append_shell_snippet() {
  local file="$1"
  local marker="$2"
  local snippet="$3"

  if [[ ! -e "$file" ]]; then
    touch "$file" 2>/dev/null || true
  fi

  if [[ -w "$file" ]] && ! grep -Fq "$marker" "$file" 2>/dev/null; then
    {
      printf '\n'
      printf '# %s\n' "$marker"
      printf '%s\n' "$snippet"
    } >> "$file"
  fi
}

persist_path_prefix() {
  local target_path="$1"
  local marker="$2"
  local file
  local -a shell_files=(
    "$HOME/.profile"
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.zprofile"
    "$HOME/.zshrc"
  )

  for file in "${shell_files[@]}"; do
    append_shell_snippet "$file" "$marker" "export PATH=\"$target_path:\$PATH\""
  done
}

if command -v deno >/dev/null 2>&1; then
  log "Deno CLI already installed; skipping."
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  log "curl is required to install Deno; skipping installation." >&2
  exit 0
fi

deno_install_root="${DENO_INSTALL_ROOT:-$HOME/.deno}"
deno_installer="$(mktemp)"
trap 'rm -f /tmp/deno-install.log "$deno_installer"' EXIT

if ! curl -fsSL https://deno.land/install.sh -o "$deno_installer"; then
  log "Failed to download Deno install script; skipping installation."
  exit 0
fi

chmod +x "$deno_installer" || true

if ! (DENO_INSTALL="$deno_install_root" \
      DENO_INSTALL_SKIP_PATH=1 \
      sh "$deno_installer" >/tmp/deno-install.log 2>&1); then
  log "Deno install script failed; leaving CLI uninstalled."
  log "Details: $(tail -n 20 /tmp/deno-install.log 2>/dev/null || echo 'see installer output')"
  exit 0
fi

# Ensure the current shell can find Deno.
case ":$PATH:" in
  *":$deno_install_root/bin:"*) ;;
  *) export PATH="$deno_install_root/bin:$PATH" ;;
esac

# Persist PATH updates for future shells when possible.
persist_path_prefix "$deno_install_root/bin" "Added by devcontainer post-create to expose Deno"

log "Deno CLI installation complete."

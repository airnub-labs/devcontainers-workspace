#!/usr/bin/env bash
set -euo pipefail

if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

log() {
  echo "[install-deno-cli] $*"
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

log "Deno CLI installation complete."

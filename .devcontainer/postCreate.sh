#!/usr/bin/env bash
set -euo pipefail

POLICY_MODE="${CHROME_POLICY_MODE:-managed}"
POLICY_SOURCE="${CHROME_POLICY_SOURCE:-}"
POLICY_TARGET=".devcontainer/policies/managed.json"
PRESET_DIR=".devcontainer/policies/presets"
MANAGED_PRESET="${PRESET_DIR}/managed.json"
NONE_PRESET="${PRESET_DIR}/none.json"

if [ ! -f "${MANAGED_PRESET}" ]; then
  MANAGED_PRESET=".devcontainer/policies/managed.json"
fi
if [ ! -f "${NONE_PRESET}" ]; then
  NONE_PRESET=".devcontainer/policies/none.json"
fi

mkdir -p "$(dirname "${POLICY_TARGET}")"

sync_policies() {
  local src="$1"
  local dest="$2"
  if [ "${src}" = "${dest}" ]; then
    return 0
  fi
  if [ -f "${src}" ]; then
    if [ ! -f "${dest}" ] || ! cmp -s "${src}" "${dest}"; then
      cp "${src}" "${dest}"
    fi
  else
    echo "[classroom-studio-webtop] Chrome policy source not found: ${src}" >&2
  fi
}

if [ -n "${POLICY_SOURCE}" ] && [ "${POLICY_SOURCE}" != "${POLICY_TARGET}" ]; then
  sync_policies "${POLICY_SOURCE}" "${POLICY_TARGET}"
else
  case "${POLICY_MODE}" in
    managed)
      sync_policies "${MANAGED_PRESET}" "${POLICY_TARGET}"
      ;;
    none)
      sync_policies "${NONE_PRESET}" "${POLICY_TARGET}"
      ;;
  esac
fi

if command -v pnpm >/dev/null 2>&1 && [ -f package.json ]; then
  pnpm install --frozen-lockfile || pnpm install
fi

if command -v supabase >/dev/null 2>&1; then
  supabase --version || true
fi

VSCODE_SERVER_BIN_DIR="${HOME}/.vscode-server/bin"
if [ -d "${VSCODE_SERVER_BIN_DIR}" ]; then
  VSCODE_CLI="$(find "${VSCODE_SERVER_BIN_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 { print $2 }')/bin/code-server"
else
  VSCODE_CLI=""
fi

cleanup_vscode_extension_temp_dirs() {
  local extensions_dir="${HOME}/.vscode-server/extensions"
  if [ -d "${extensions_dir}" ]; then
    find "${extensions_dir}" -mindepth 1 -maxdepth 1 -type d -name '.*' -exec rm -rf {} +
  fi
}

install_vscode_extension() {
  local extension="$1"
  local extensions_dir="${HOME}/.vscode-server/extensions"

  if [ -z "${VSCODE_CLI}" ] || [ ! -x "${VSCODE_CLI}" ]; then
    echo "[postCreate] Skipping ${extension} install; VS Code CLI not available yet." >&2
    return 0
  fi

  if "${VSCODE_CLI}" --list-extensions | grep -qx "${extension}"; then
    return 0
  fi

  if [ -d "${extensions_dir}" ]; then
    find "${extensions_dir}" -mindepth 1 -maxdepth 1 -type d -name "${extension}-*" -exec rm -rf {} +
  fi

  if ! "${VSCODE_CLI}" --install-extension "${extension}" --force; then
    echo "[postCreate] Failed to install VS Code extension ${extension}." >&2
    return 0
  fi

  sleep 2
}

if [ -n "${VSCODE_CLI}" ] && [ -x "${VSCODE_CLI}" ]; then
  cleanup_vscode_extension_temp_dirs || true
  install_vscode_extension "github.copilot"
  install_vscode_extension "github.copilot-chat"
fi

#!/usr/bin/env bash
set -euo pipefail

POLICY_MODE="{{templateOption.policyMode}}"
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

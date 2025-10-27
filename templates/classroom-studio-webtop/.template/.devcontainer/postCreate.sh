#!/usr/bin/env bash
set -euo pipefail

POLICY_MODE="{{templateOption.policyMode}}"
POLICY_FILE="${CHROME_POLICY_FILE:-.devcontainer/policies/${POLICY_MODE}.json}"

policy_dir="$(dirname "${POLICY_FILE}")"
mkdir -p "${policy_dir}"

case "${POLICY_MODE}" in
  managed)
    if [ ! -f "${POLICY_FILE}" ]; then
      cp .devcontainer/policies/managed.json "${POLICY_FILE}"
    fi
    ;;
  none)
    if [ ! -f "${POLICY_FILE}" ]; then
      cp .devcontainer/policies/none.json "${POLICY_FILE}"
    fi
    ;;
esac

if command -v pnpm >/dev/null 2>&1 && [ -f package.json ]; then
  pnpm install --frozen-lockfile || pnpm install
fi

if command -v supabase >/dev/null 2>&1; then
  supabase --version || true
fi

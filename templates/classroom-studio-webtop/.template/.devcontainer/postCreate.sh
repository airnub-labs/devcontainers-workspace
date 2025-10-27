#!/usr/bin/env bash
set -euo pipefail

POLICY_MODE="{{templateOption.policyMode}}"
POLICY_FILE="${CHROME_POLICY_FILE:-.devcontainer/policies/managed.json}"

if [ "${POLICY_MODE}" = "managed" ]; then
  policy_dir="$(dirname "${POLICY_FILE}")"
  mkdir -p "${policy_dir}"
  if [ ! -f "${POLICY_FILE}" ]; then
    cp .devcontainer/policies/managed.json "${POLICY_FILE}"
  fi
fi

if command -v pnpm >/dev/null 2>&1 && [ -f package.json ]; then
  pnpm install --frozen-lockfile || pnpm install
fi

if command -v supabase >/dev/null 2>&1; then
  supabase --version || true
fi

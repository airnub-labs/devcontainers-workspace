#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPABASE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${SUPABASE_ROOT}/.." && pwd)"
CONFIG_TOML="${SUPABASE_ROOT}/config.toml"
SUPABASE_ENV_HELPER="${SUPABASE_ROOT}/scripts/db-env-local.sh"
SHARED_ENV_FILE="${SUPABASE_ROOT}/.env.local"
PROJECT_ENV_FILE="${PROJECT_ENV_FILE:-$(pwd)/.env.local}"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

error() {
  echo "[use-shared-supabase] $*" >&2
}

info() {
  echo "[use-shared-supabase] $*"
}

if ! command -v supabase >/dev/null 2>&1; then
  error "Supabase CLI is not on PATH. Install it inside the workspace container first."
  exit 1
fi

if [[ ! -f "${CONFIG_TOML}" ]]; then
  error "Shared Supabase config not found at ${CONFIG_TOML}."
  exit 1
fi

PROJECT_REF="${SUPABASE_PROJECT_REF:-}"
if [[ -z "${PROJECT_REF}" ]]; then
  PROJECT_REF="$(awk -F '"' '/^project_id/ {print $2; exit}' "${CONFIG_TOML}" 2>/dev/null || true)"
fi

if [[ -z "${PROJECT_REF}" ]]; then
  error "Could not determine project ref. Set SUPABASE_PROJECT_REF or ensure config.toml has project_id."
  exit 1
fi

if [[ ! -d "${WORKSPACE_ROOT}" ]]; then
  error "Could not determine workspace root (looked for parent of ${SUPABASE_ROOT})."
  exit 1
fi

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "Project directory not found: ${PROJECT_DIR}"
  exit 1
fi

PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"

sync_shared_env() {
  local ensure_start="${1:-true}"

  if [[ -x "${SUPABASE_ENV_HELPER}" ]]; then
    if ! SUPABASE_PROJECT_DIR="${SUPABASE_ROOT}" "${SUPABASE_ENV_HELPER}" --status-only >/dev/null 2>&1; then
      if [[ "${ensure_start}" == "true" ]]; then
        info "Shared Supabase env vars not available via status; trying '--ensure-start'."
        if ! SUPABASE_PROJECT_DIR="${SUPABASE_ROOT}" "${SUPABASE_ENV_HELPER}" --ensure-start >/dev/null 2>&1; then
          error "Could not refresh Supabase env vars via db-env-local.sh."
        fi
      else
        error "Supabase stack does not appear to be running; env vars may be stale."
      fi
    fi
  fi

  if [[ ! -f "${SHARED_ENV_FILE}" ]]; then
    error "Shared Supabase env file missing at ${SHARED_ENV_FILE}."
    return 1
  fi

  local tmp_env
  tmp_env="$(mktemp)"

  cp "${SHARED_ENV_FILE}" "${tmp_env}"

  # Ensure output ends with newline for clean appends
  if [[ -s "${tmp_env}" && $(tail -c1 "${tmp_env}" 2>/dev/null) != $'\n' ]]; then
    echo >>"${tmp_env}"
  fi

  declare -A shared_keys=()
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    local key
    key="${line%%=*}"
    key="${key%%[[:space:]]*}"
    shared_keys["${key}"]=1
  done <"${SHARED_ENV_FILE}"

  # Prune deprecated Supabase key names so projects swap to the new publishable/secret pair.
  local legacy_keys=(
    SUPABASE_ANON_KEY
    SUPABASE_SERVICE_ROLE_KEY
  )

  for legacy_key in "${legacy_keys[@]}"; do
    shared_keys["${legacy_key}"]=1
  done

  if [[ -f "${PROJECT_ENV_FILE}" ]]; then
    local -a custom_lines=()
    while IFS= read -r line || [[ -n "${line}" ]]; do
      if [[ "${line}" =~ ^[[:space:]]*$ ]]; then
        custom_lines+=("${line}")
        continue
      fi

      if [[ "${line}" =~ ^[[:space:]]*# ]]; then
        custom_lines+=("${line}")
        continue
      fi

      local key
      key="${line%%=*}"
      key="${key%%[[:space:]]*}"

      if [[ -n "${key}" && -n "${shared_keys[$key]+x}" ]]; then
        continue
      fi

      custom_lines+=("${line}")
    done <"${PROJECT_ENV_FILE}"

    if ((${#custom_lines[@]} > 0)); then
      echo >>"${tmp_env}"
      echo "# Project-specific environment variables (preserved)" >>"${tmp_env}"
      for line in "${custom_lines[@]}"; do
        echo "${line}" >>"${tmp_env}"
      done
    fi
  fi

  mv "${tmp_env}" "${PROJECT_ENV_FILE}"
  chmod 600 "${PROJECT_ENV_FILE}" 2>/dev/null || true
  info "Synced Supabase env vars to ${PROJECT_ENV_FILE} (custom entries preserved)."
}

COMMAND="${1:-push}"
shift || true

case "${COMMAND}" in
  push)
    if ! sync_shared_env true; then
      error "Continuing with push even though env sync failed."
    fi
    echo "[use-shared-supabase] Applying migrations from ${PROJECT_DIR} via workspace ${WORKSPACE_ROOT} (project ref: ${PROJECT_REF})."
    (cd "${WORKSPACE_ROOT}" && supabase db push --workdir "${PROJECT_DIR}" --local "$@")
    ;;
  reset)
    if ! sync_shared_env true; then
      error "Continuing with reset even though env sync failed."
    fi
    echo "[use-shared-supabase] WARNING: Resetting shared stack for ${PROJECT_DIR} via workspace ${WORKSPACE_ROOT}. This wipes existing data."
    (cd "${WORKSPACE_ROOT}" && supabase db reset --workdir "${PROJECT_DIR}" --local -y "$@")
    ;;
  status)
    if ! sync_shared_env false; then
      error "Status reported without refreshing shared env vars."
    fi
    echo "[use-shared-supabase] Checking shared stack status for ${PROJECT_DIR} via workspace ${WORKSPACE_ROOT} (project ref: ${PROJECT_REF})."
    (cd "${WORKSPACE_ROOT}" && supabase status -o env --workdir "${PROJECT_DIR}" "$@")
    ;;
  *)
    cat <<USAGE >&2
Usage: $(basename "$0") [push|reset|status] [additional supabase args]

push   - Run 'supabase db push --workdir <project> --local' against the shared stack.
reset  - Run 'supabase db reset --workdir <project> --local -y' (destructive).
status - Run 'supabase status -o env --workdir <project>'.

Set SUPABASE_PROJECT_REF if the shared stack uses a different ref.
USAGE
    exit 1
    ;;
esac

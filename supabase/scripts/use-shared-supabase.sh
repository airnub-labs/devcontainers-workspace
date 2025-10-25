#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_repo_root() {
  local dir="$SCRIPT_DIR"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/airnub" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    if [[ -d "$dir/.git" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

REPO_ROOT="${REPO_ROOT:-$(find_repo_root || true)}"
if [[ -z "$REPO_ROOT" ]]; then
  echo "[use-shared-supabase] Could not locate the repository root. Set AIRNUB_CLI or REPO_ROOT explicitly." >&2
  exit 1
fi

SUPABASE_ROOT="${SUPABASE_ROOT:-${REPO_ROOT}/supabase}"
AIRNUB_CLI="${AIRNUB_CLI:-${REPO_ROOT}/airnub}"

if [[ ! -d "$SUPABASE_ROOT" ]]; then
  echo "[use-shared-supabase] Supabase directory not found at $SUPABASE_ROOT." >&2
  exit 1
fi

if [[ ! -x "$AIRNUB_CLI" ]]; then
  echo "[use-shared-supabase] airnub CLI not found at $AIRNUB_CLI. Run this script from the repository root." >&2
  exit 1
fi

PROJECT_DIR="${PROJECT_DIR:-${SUPABASE_ROOT}}"
PROJECT_ENV_FILE="${PROJECT_ENV_FILE:-}"
SKIP_SHARED_ENV_SYNC="${SKIP_SHARED_ENV_SYNC:-false}"
SHARED_ENV_ENSURE_START="${SHARED_ENV_ENSURE_START:-auto}"
SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-}"

COMMAND="${1:-push}"
shift || true

case "$COMMAND" in
  push)
    AIRNUB_DB_SUBCOMMAND="apply"
    ;;
  reset)
    AIRNUB_DB_SUBCOMMAND="reset"
    ;;
  status)
    AIRNUB_DB_SUBCOMMAND="status"
    ;;
  *)
    cat <<'USAGE' >&2
Usage: use-shared-supabase.sh [push|reset|status] [-- <supabase args>]

push   - Run 'airnub db apply' for the chosen project (defaults to supabase/).
reset  - Run 'airnub db reset' (destructive) for the chosen project.
status - Run 'airnub db status' for the chosen project.
USAGE
    exit 1
    ;;
esac

declare -a args=("$AIRNUB_CLI" db "$AIRNUB_DB_SUBCOMMAND")

if [[ -n "$PROJECT_DIR" ]]; then
  args+=(--project-dir "$PROJECT_DIR")
fi

if [[ -n "$PROJECT_ENV_FILE" ]]; then
  args+=(--project-env-file "$PROJECT_ENV_FILE")
fi

if [[ -n "$SUPABASE_PROJECT_REF" ]]; then
  args+=(--project-ref "$SUPABASE_PROJECT_REF")
fi

case "$SHARED_ENV_ENSURE_START" in
  true)
    args+=(--ensure-env-sync)
    ;;
  false)
    args+=(--status-only-env-sync)
    ;;
  auto)
    ;;
  *)
    echo "[use-shared-supabase] Unknown SHARED_ENV_ENSURE_START value: $SHARED_ENV_ENSURE_START" >&2
    exit 1
    ;;
esac

if [[ "$SKIP_SHARED_ENV_SYNC" == "true" ]]; then
  args+=(--skip-env-sync)
fi

if [[ $# -gt 0 ]]; then
  args+=(-- "$@")
fi

exec "${args[@]}"

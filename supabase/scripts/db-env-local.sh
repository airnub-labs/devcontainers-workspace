#!/usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  [[ "${DEBUG:-false}" == "true" ]] && set -x
fi

SUPABASE_ENV_LOG_PREFIX="${SUPABASE_ENV_LOG_PREFIX:-[db:env:local]}"
SUPABASE_ENV_LAST_STDOUT=""
SUPABASE_ENV_LAST_STDERR=""

supabase_env_log() {
  local message="$1"
  printf '%s %s\n' "$SUPABASE_ENV_LOG_PREFIX" "$message"
}

supabase_env_error() {
  local message="$1"
  printf '%s %s\n' "$SUPABASE_ENV_LOG_PREFIX" "$message" >&2
}

supabase_env_init() {
  if ! command -v supabase >/dev/null 2>&1; then
    supabase_env_error "Supabase CLI not found on PATH."
    return 1
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -n "${SUPABASE_PROJECT_DIR:-}" ]]; then
    if [[ ! -d "$SUPABASE_PROJECT_DIR" ]]; then
      supabase_env_error "SUPABASE_PROJECT_DIR does not exist: $SUPABASE_PROJECT_DIR"
      return 1
    fi
    SUPABASE_PROJECT_DIR="$(cd "$SUPABASE_PROJECT_DIR" && pwd)"
  else
    SUPABASE_PROJECT_DIR="$(cd "$script_dir/.." && pwd)"
  fi

  SUPABASE_ENV_FILE="${SUPABASE_ENV_FILE:-$SUPABASE_PROJECT_DIR/.env.local}"
  if [[ ! -d "$(dirname "$SUPABASE_ENV_FILE")" ]]; then
    mkdir -p "$(dirname "$SUPABASE_ENV_FILE")"
  fi

  if [[ ! -f "$SUPABASE_PROJECT_DIR/config.toml" ]]; then
    supabase_env_error "Supabase config not found (expected $SUPABASE_PROJECT_DIR/config.toml)."
    return 1
  fi

  if [[ -z "${SUPABASE_PROJECT_REF:-}" ]]; then
    local env_ref="${SHARED_SUPABASE_PROJECT_REF:-${AIRNUB_SUPABASE_PROJECT_REF:-}}"
    if [[ -n "$env_ref" ]]; then
      SUPABASE_PROJECT_REF="$env_ref"
    else
      local config_ref
      config_ref="$(awk -F '"' '/^project_id/ {print $2; exit}' "$SUPABASE_PROJECT_DIR/config.toml" 2>/dev/null || true)"
      if [[ -n "$config_ref" ]]; then
        SUPABASE_PROJECT_REF="$config_ref"
      fi
    fi
  fi

  if [[ -n "${SUPABASE_PROJECT_REF:-}" ]]; then
    export SUPABASE_PROJECT_REF
  fi

  return 0
}

supabase_env_format_env_file() {
  local input_file="$1"
  local output_file="$2"

  local tmp_formatted
  tmp_formatted="$(mktemp)"

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading whitespace without using external tools.
    local trimmed="${line#${line%%[!$' \t']*}}"

    # Skip empty lines entirely.
    if [[ -z "$trimmed" ]]; then
      continue
    fi

    # Preserve already well-formed env assignments.
    if [[ "$trimmed" == *=* && "$trimmed" != *": "* ]]; then
      printf '%s\n' "$trimmed" >>"$tmp_formatted"
      continue
    fi

    # Convert "Label: value" pairs to SUPABASE_* env vars.
    if [[ "$trimmed" == *":"* ]]; then
      local key="${trimmed%%:*}"
      local value="${trimmed#*:}"
      value="${value#${value%%[!$' \t']*}}"

      key="${key//[^[:alnum:]]/_}"
      key="${key^^}"
      key="SUPABASE_${key}"

      printf '%s=%s\n' "$key" "$value" >>"$tmp_formatted"
      continue
    fi

    # Fallback: keep the line as a comment for debugging context.
    printf '# %s\n' "$trimmed" >>"$tmp_formatted"
  done <"$input_file"

  mv "$tmp_formatted" "$output_file"
  rm -f "$input_file"
}

supabase_env_run_command() {
  local command="$1"
  local destination="$2"

  SUPABASE_ENV_LAST_STDOUT=""
  SUPABASE_ENV_LAST_STDERR=""

  local tmp_env
  local tmp_err
  tmp_env="$(mktemp)"
  tmp_err="$(mktemp)"

  local rc=1

  if (cd "$SUPABASE_PROJECT_DIR" && supabase "$command" -o env >"$tmp_env" 2>"$tmp_err"); then
    if [[ -s "$tmp_env" ]]; then
      supabase_env_format_env_file "$tmp_env" "$destination"
      rm -f "$tmp_err"
      chmod 600 "$destination" 2>/dev/null || true
      return 0
    fi
    rc=0
  fi

  if [[ -s "$tmp_env" ]]; then
    SUPABASE_ENV_LAST_STDOUT="$(<"$tmp_env")"
  fi

  if [[ -s "$tmp_err" ]]; then
    SUPABASE_ENV_LAST_STDERR="$(<"$tmp_err")"
  elif [[ "$rc" -eq 0 ]]; then
    SUPABASE_ENV_LAST_STDERR="supabase $command -o env did not produce any output."
  fi

  rm -f "$tmp_env" "$tmp_err"
  return $rc
}

supabase_env_status() {
  supabase_env_run_command status "$SUPABASE_ENV_FILE"
}

supabase_env_start() {
  if supabase_env_run_command start "$SUPABASE_ENV_FILE"; then
    return 0
  fi

  local lower_stdout="${SUPABASE_ENV_LAST_STDOUT,,}"
  local lower_stderr="${SUPABASE_ENV_LAST_STDERR,,}"

  if [[ "$lower_stdout" == *"already running"* || "$lower_stderr" == *"already running"* ]]; then
    return supabase_env_status
  fi

  return 1
}

supabase_env_sync() {
  local ensure_start="${1:-true}"

  if supabase_env_status; then
    supabase_env_log "Wrote Supabase status env vars to $SUPABASE_ENV_FILE."
    return 0
  fi

  if [[ "$ensure_start" != "true" ]]; then
    supabase_env_error "Supabase stack is not running; skipping env sync."
    return 1
  fi

  supabase_env_log "Supabase stack not running; starting via 'supabase start -o env'."
  if supabase_env_start; then
    supabase_env_log "Supabase services started; env vars written to $SUPABASE_ENV_FILE."
    return 0
  fi

  if [[ -n "$SUPABASE_ENV_LAST_STDERR" ]]; then
    supabase_env_error "$SUPABASE_ENV_LAST_STDERR"
  fi
  supabase_env_error "Failed to capture Supabase env vars."
  return 1
}

supabase_env_main() {
  if ! supabase_env_init; then
    return 1
  fi

  local ensure_start=true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status-only)
        ensure_start=false
        shift
        ;;
      --ensure-start)
        ensure_start=true
        shift
        ;;
      --env-file)
        SUPABASE_ENV_FILE="$2"
        shift 2
        ;;
      --project-dir)
        SUPABASE_PROJECT_DIR="$2"
        shift 2
        ;;
      --help|-h)
        cat <<'USAGE'
Usage: db-env-local.sh [options]
  --ensure-start    Start Supabase if it is not already running (default).
  --status-only     Only read env vars from an already-running stack.
  --env-file PATH   Write env vars to PATH instead of supabase/.env.local.
  --project-dir DIR Supabase project directory (default: supabase/).
USAGE
        return 0
        ;;
      *)
        supabase_env_error "Unknown option: $1"
        return 1
        ;;
    esac
  done

  supabase_env_sync "$ensure_start"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  supabase_env_main "$@"
fi

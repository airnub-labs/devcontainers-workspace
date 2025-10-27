#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

trap 'ec=$?; if [[ $ec -ne 0 ]]; then echo "[supabase-stack] error: exited with code $ec"; fi' EXIT

determine_repo_root() {
  if command -v git >/dev/null 2>&1; then
    if root=$(git rev-parse --show-toplevel 2>/dev/null); then
      printf '%s\n' "$root"
      return 0
    fi
  fi
  pwd
}

REPO_ROOT="$(determine_repo_root)"
cd "${REPO_ROOT}" || exit 1

SUPABASE_PROJECT_DIR="${SUPABASE_PROJECT_DIR:-$REPO_ROOT/supabase}"
SUPABASE_CONFIG_PATH="${SUPABASE_CONFIG_PATH:-$SUPABASE_PROJECT_DIR/config.toml}"
WORKSPACE_STACK_NAME="${WORKSPACE_STACK_NAME:-${AIRNUB_WORKSPACE_NAME:-airnub-labs}}"
DEVCONTAINER_PROJECT_NAME="${DEVCONTAINER_PROJECT_NAME:-$WORKSPACE_STACK_NAME}"

LOG_DIR="${DEVCONTAINER_LOG_DIR:-/var/log/devcontainer}"
LOG_FILE="${DEVCONTAINER_LOG_FILE:-$LOG_DIR/devcontainer.log}"
mkdir -p "$LOG_DIR" 2>/dev/null || true
: >>"$LOG_FILE" 2>/dev/null || true

log() {
  local message="[supabase-stack] $*"
  echo "$message"
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "$message" >>"$LOG_FILE" 2>/dev/null || true
  fi
}

DOCKER_WAIT_ATTEMPTS="${SUPABASE_DOCKER_WAIT_ATTEMPTS:-${DOCKER_WAIT_ATTEMPTS:-40}}"
DOCKER_WAIT_SLEEP_SECS="${SUPABASE_DOCKER_WAIT_SLEEP_SECS:-${DOCKER_WAIT_SLEEP_SECS:-2}}"

wait_for_docker_daemon() {
  local max_attempts="${1:-30}"
  local sleep_seconds="${2:-2}"
  for attempt in $(seq 1 "$max_attempts"); do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    if [[ "$attempt" -eq 1 ]]; then
      log "Waiting for Docker daemon to become ready before bootstrapping Supabase..."
    fi
    sleep "$sleep_seconds"
  done
  return 1
}

ensure_supabase_stack() {
  local supabase_dir="$SUPABASE_PROJECT_DIR"
  local supabase_start_args=()

  if [[ -n "${SUPABASE_START_ARGS:-}" ]]; then
    # shellcheck disable=SC2206  # Intentional word splitting for user-provided args
    supabase_start_args+=(${SUPABASE_START_ARGS})
  fi
  if [[ -n "${SUPABASE_START_EXCLUDES:-}" ]]; then
    local exclude
    # shellcheck disable=SC2086  # Honour user input
    for exclude in ${SUPABASE_START_EXCLUDES}; do
      supabase_start_args+=(-x "$exclude")
    done
  fi

  local compose_project_name="${WORKSPACE_STACK_NAME}-supabase"

  if (
    cd "$supabase_dir" &&
    COMPOSE_PROJECT_NAME="$compose_project_name" \
      supabase status >/dev/null 2>&1
  ); then
    log "Supabase stack already running inside the inner Docker daemon."
    return 0
  fi

  local start_display="supabase start"
  if [[ ${#supabase_start_args[@]} -gt 0 ]]; then
    start_display+=" ${supabase_start_args[*]}"
  fi

  local supabase_volumes_dir="$supabase_dir/docker/volumes"
  local supabase_db_dir="$supabase_volumes_dir/db"
  local supabase_minio_dir="$supabase_volumes_dir/minio"

  mkdir -p "$supabase_db_dir" "$supabase_minio_dir"

  log "Supabase stack not running; starting via '$start_display'..."
  if (
    cd "$supabase_dir" &&
    COMPOSE_PROJECT_NAME="$compose_project_name" \
      supabase start "${supabase_start_args[@]}" 2>&1 | tee -a "$LOG_FILE"
  ); then
    log "Supabase stack started successfully."
    return 0
  fi

  log "Failed to start Supabase stack; see Supabase CLI output above for details."
  return 1
}

log "Supabase stack bootstrap running..."

docker_ready=false
if command -v docker >/dev/null 2>&1; then
  if wait_for_docker_daemon "$DOCKER_WAIT_ATTEMPTS" "$DOCKER_WAIT_SLEEP_SECS"; then
    docker_ready=true
  else
    log "Docker daemon did not become ready; Supabase startup skipped."
  fi
else
  log "Docker CLI not available; Supabase startup skipped."
fi

if ! command -v supabase >/dev/null 2>&1; then
  log "Supabase CLI not found on PATH; Supabase startup skipped."
  exit 0
fi

if [[ ! -d "$SUPABASE_PROJECT_DIR" || ! -f "$SUPABASE_CONFIG_PATH" ]]; then
  log "Supabase configuration not found (expected $SUPABASE_CONFIG_PATH); Supabase startup skipped."
  exit 0
fi

if [[ "$docker_ready" != "true" ]]; then
  exit 0
fi

supabase_env_helper="$SUPABASE_PROJECT_DIR/scripts/db-env-local.sh"
if ensure_supabase_stack; then
  if [[ -x "$supabase_env_helper" ]]; then
    if SUPABASE_ENV_LOG_PREFIX="[supabase-stack]" "$supabase_env_helper" --status-only; then
      log "Supabase environment variables synchronised."
    else
      log "Supabase env helper failed; env vars were not updated automatically."
    fi
  else
    log "Supabase env helper not found at $supabase_env_helper; skipping automatic env sync."
  fi
else
  log "Supabase stack was not confirmed ready during bootstrap."
fi

log "Supabase stack bootstrap complete."

#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

# Log non‑zero exits to the devcontainer log
trap 'ec=$?; if [[ $ec -ne 0 ]]; then echo "[post-start] error: exited with code $ec"; fi' EXIT

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
SUPABASE_PROJECT_DIR="${SUPABASE_PROJECT_DIR:-$REPO_ROOT/supabase}"
SUPABASE_CONFIG_PATH="${SUPABASE_CONFIG_PATH:-$SUPABASE_PROJECT_DIR/config.toml}"
WORKSPACE_STACK_NAME="${WORKSPACE_STACK_NAME:-${AIRNUB_WORKSPACE_NAME:-airnub-labs}}"
DEVCONTAINER_PROJECT_NAME="${DEVCONTAINER_PROJECT_NAME:-$WORKSPACE_STACK_NAME}"

LOG_DIR="${DEVCONTAINER_LOG_DIR:-/var/log/devcontainer}"
LOG_FILE="${DEVCONTAINER_LOG_FILE:-$LOG_DIR/devcontainer.log}"
mkdir -p "$LOG_DIR" 2>/dev/null || true
: >"$LOG_FILE" 2>/dev/null || true

export WORKSPACE_STACK_NAME
export DEVCONTAINER_PROJECT_NAME
if [[ -z "${WORKSPACE_CONTAINER_ROOT:-}" ]]; then
  WORKSPACE_CONTAINER_ROOT="/airnub-labs"
fi
export WORKSPACE_CONTAINER_ROOT

# Optional sudo prefix (not guaranteed in containers)
SUDO=""
if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi

log() {
  local message="[post-start] $*"
  echo "$message"
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "$message" >>"$LOG_FILE" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Docker & Supabase detection
# ---------------------------------------------------------------------------

# Make Docker wait tunable via env
DOCKER_WAIT_ATTEMPTS="${DOCKER_WAIT_ATTEMPTS:-40}"
DOCKER_WAIT_SLEEP_SECS="${DOCKER_WAIT_SLEEP_SECS:-2}"

authenticate_ecr_public_registry() {
  if [[ "$docker_ready" != "true" ]]; then return 0; fi
  if ! command -v aws >/dev/null 2>&1; then
    log "AWS CLI not available; skipping Amazon ECR Public authentication."
    return 0
  fi
  log "Authenticating to Amazon ECR Public registry to raise pull rate limits..."
  if aws ecr-public get-login-password --region us-east-1 \
    | docker login --username AWS --password-stdin public.ecr.aws >/dev/null 2>&1; then
    log "Amazon ECR Public authentication succeeded."
    return 0
  fi
  log "Amazon ECR Public authentication failed; Supabase image pulls may be rate limited."
  return 1
}

wait_for_docker_daemon() {
  local max_attempts="${1:-30}"
  local sleep_seconds="${2:-2}"
  for attempt in $(seq 1 "$max_attempts"); do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    if [[ "$attempt" -eq 1 ]]; then
      log "Waiting for Docker daemon to become ready..."
    fi
    sleep "$sleep_seconds"
  done
  return 1
}

docker_cli_present=false
docker_ready=false
supabase_cli_present=false
supabase_project_available=false

if command -v docker >/dev/null 2>&1; then
  docker_cli_present=true
  if wait_for_docker_daemon "$DOCKER_WAIT_ATTEMPTS" "$DOCKER_WAIT_SLEEP_SECS"; then
    docker_ready=true
  else
    log "Docker daemon did not become ready; Docker-dependent services will be skipped."
  fi
else
  log "Docker CLI not available; Docker-dependent services will be skipped."
fi

if command -v supabase >/dev/null 2>&1; then
  supabase_cli_present=true
else
  log "Supabase CLI not found on PATH; Supabase startup will be skipped."
fi

if [[ -d "$SUPABASE_PROJECT_DIR" && -f "$SUPABASE_CONFIG_PATH" ]]; then
  supabase_project_available=true
else
  log "Supabase configuration not found (expected $SUPABASE_CONFIG_PATH); Supabase startup will be skipped."
fi

supabase_stack_ready=false
supabase_env_synced=false
redis_container_ready=false

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

ensure_inner_redis() {
  local container_name="redis"
  local container_image="redis:7-alpine"
  local host_port="6379"

  # Identify if another container already binds the desired host port
  local port_owner
  port_owner="$(
    docker ps --format '{{.Names}} {{.Ports}}' |
      awk -v port="$host_port" '
        {
          name=$1
          $1=""
          if ($0 ~ ":" port "->") {
            print name
          }
        }
      ' |
      head -n 1
  )"

  if docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
    log "Redis container already running inside the inner Docker daemon."
    return 0
  fi

  if [[ -n "$port_owner" && "$port_owner" != "$container_name" ]]; then
    log "Host port $host_port is already bound by container '$port_owner'; skipping Redis startup."
    log "Stop the conflicting container or free port $host_port, then rerun 'docker start $container_name'."
    return 1
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx "$container_name"; then
    log "Starting existing Redis container inside the inner Docker daemon..."
    if docker start "$container_name" >/dev/null; then
      log "Redis container started."
      return 0
    fi
    log "Failed to start existing Redis container named '$container_name'."
    return 1
  fi

  log "Launching Redis container inside the inner Docker daemon..."
  if docker run -d --name "$container_name" -p "$host_port:$host_port" "$container_image" >/dev/null; then
    log "Redis container launched."
    return 0
  fi

  log "Failed to launch Redis container via 'docker run'."
  return 1
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------
if [[ "$docker_ready" == "true" ]]; then
  authenticate_ecr_public_registry || true
fi

if [[ "$docker_ready" == "true" && "$supabase_cli_present" == "true" && "$supabase_project_available" == "true" ]]; then
  supabase_env_helper="$SUPABASE_PROJECT_DIR/scripts/db-env-local.sh"
  if ensure_supabase_stack; then
    supabase_stack_ready=true
    if [[ -x "$supabase_env_helper" ]]; then
      if SUPABASE_ENV_LOG_PREFIX="[post-start]" "$supabase_env_helper" --status-only; then
        supabase_env_synced=true
      else
        log "Supabase env helper failed; env vars were not updated automatically."
      fi
    else
      log "Supabase env helper not found at $supabase_env_helper; skipping automatic env sync."
    fi
  fi
elif [[ "$supabase_cli_present" != "true" ]]; then
  log "Skipping Supabase startup because the Supabase CLI is unavailable."
elif [[ "$supabase_project_available" != "true" ]]; then
  log "Skipping Supabase startup because supabase/config.toml is missing."
elif [[ "$docker_ready" != "true" ]]; then
  log "Skipping Supabase startup because Docker is unavailable."
fi

if [[ "$docker_ready" == "true" ]]; then
  if ensure_inner_redis; then
    redis_container_ready=true
  fi
else
  log "Docker unavailable; unable to manage Redis container."
fi

if [[ "$supabase_stack_ready" != "true" && "$supabase_cli_present" == "true" && "$supabase_project_available" == "true" ]]; then
  log "Supabase stack was not confirmed ready during post-start."
fi

if [[ "$supabase_env_synced" != "true" && "$supabase_cli_present" == "true" && "$supabase_project_available" == "true" ]]; then
  log "Supabase env vars were not synced automatically; run './supabase/scripts/db-env-local.sh --ensure-start' once the stack is ready."
fi

if [[ "$redis_container_ready" != "true" && "$docker_ready" == "true" ]]; then
  log "Redis container was not started automatically. Use 'docker start redis' when ready."
fi

# ---------------------------------------------------------------------------
# OPTIONAL: Repo clone support (non-breaking)
# ---------------------------------------------------------------------------
WORKSPACE_ROOT_DEFAULT="$(dirname "$REPO_ROOT")"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$WORKSPACE_ROOT_DEFAULT}"

WS_FILE="$(find "$REPO_ROOT" -maxdepth 1 -name "*.code-workspace" | head -n 1 || true)"
if [[ -z "$WS_FILE" ]]; then
  ws_basename="${WORKSPACE_CODE_WORKSPACE_BASENAME:-$WORKSPACE_STACK_NAME}"
  WS_FILE="$REPO_ROOT/${ws_basename}.code-workspace"
fi

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then return 0; fi
  if command -v apt-get >/dev/null 2>&1; then
    log "jq not found; installing via apt-get..."
    $SUDO apt-get update -y && $SUDO apt-get install -y jq \
      || log "jq install failed; proceeding without it"
  else
    log "jq not available and apt-get missing; workspace checks limited"
  fi
}

list_workspace_repo_names() {
  if [[ ! -f "$WS_FILE" ]]; then return 0; fi
  if command -v jq >/dev/null 2>&1; then
    jq -r '.folders[].path' "$WS_FILE" 2>/dev/null | awk -F/ '{print $NF}' | sed '/^\.$/d'
  else
    python3 - "$WS_FILE" <<'PY' || true
import json, sys
try:
  with open(sys.argv[1]) as f:
    data=json.load(f)
  for folder in data.get('folders', []):
    p=folder.get('path')
    if p and p not in ('.', '.devcontainer'):
      print(p.split('/')[-1])
except Exception:
  pass
PY
  fi
}

if [[ "${CLONE_ON_START:-false}" == "true" && -x "$SCRIPT_DIR/clone-from-devcontainer-repos.sh" ]]; then
  ensure_jq
  log "CLONE_ON_START=true → invoking clone-from-devcontainer-repos.sh"
  ALLOW_WILDCARD=0 \
  bash "$SCRIPT_DIR/clone-from-devcontainer-repos.sh" || log "Clone-on-start failed (non-fatal)"
else
  ensure_jq
  missing=()
  while IFS= read -r name; do
    [[ -z "$name" || "$name" == ".devcontainer" ]] && continue
    if [[ ! -d "$WORKSPACE_ROOT/$name/.git" ]]; then
      missing+=("$name")
    fi
  done < <(list_workspace_repo_names)

  if (( ${#missing[@]} > 0 )); then
    log "Detected missing repo clones: ${missing[*]}"
    log "Hint: Run:"
    log "      ALLOW_WILDCARD=0 bash \"$SCRIPT_DIR/clone-from-devcontainer-repos.sh\""
  fi
fi

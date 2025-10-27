#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

trap 'ec=$?; if [[ $ec -ne 0 ]]; then echo "[dind-helpers] error: exited with code $ec"; fi' EXIT

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

SUDO=""
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

log() {
  local message="[dind-helpers] $*"
  echo "$message"
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "$message" >>"$LOG_FILE" 2>/dev/null || true
  fi
}

DOCKER_WAIT_ATTEMPTS="${DOCKER_WAIT_ATTEMPTS:-40}"
DOCKER_WAIT_SLEEP_SECS="${DOCKER_WAIT_SLEEP_SECS:-2}"

authenticate_ecr_public_registry() {
  if [[ "$docker_ready" != "true" ]]; then
    return 0
  fi
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
  log "Amazon ECR Public authentication failed; image pulls may be rate limited."
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

ensure_inner_redis() {
  local container_name="redis"
  local container_image="redis:7-alpine"
  local host_port="6379"

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

log "Docker-in-Docker helper start-up running..."

docker_cli_present=false
docker_ready=false
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

if [[ "$docker_ready" == "true" ]]; then
  authenticate_ecr_public_registry || true
  if ensure_inner_redis; then
    log "Redis container ensured inside the inner Docker daemon."
  else
    log "Redis container was not started automatically. Use 'docker start redis' when ready."
  fi
else
  log "Docker unavailable; unable to manage Redis container or authenticate registries."
fi

WORKSPACE_ROOT_DEFAULT="$(dirname "$REPO_ROOT")"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$WORKSPACE_ROOT_DEFAULT}"

WS_FILE="$(find "$REPO_ROOT" -maxdepth 1 -name "*.code-workspace" | head -n 1 || true)"
if [[ -z "$WS_FILE" ]]; then
  ws_basename="${WORKSPACE_CODE_WORKSPACE_BASENAME:-$WORKSPACE_STACK_NAME}"
  WS_FILE="$REPO_ROOT/${ws_basename}.code-workspace"
fi

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    log "jq not found; installing via apt-get..."
    $SUDO apt-get update -y && $SUDO apt-get install -y jq \
      || log "jq install failed; proceeding without it"
  else
    log "jq not available and apt-get missing; workspace checks limited"
  fi
}

list_workspace_repo_names() {
  if [[ ! -f "$WS_FILE" ]]; then
    return 0
  fi
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

CLONE_SCRIPT="$REPO_ROOT/.devcontainer/scripts/clone-from-devcontainer-repos.sh"
if [[ "${CLONE_ON_START:-false}" == "true" && -x "$CLONE_SCRIPT" ]]; then
  ensure_jq
  log "CLONE_ON_START=true → invoking clone-from-devcontainer-repos.sh"
  ALLOW_WILDCARD=0 \
  bash "$CLONE_SCRIPT" || log "Clone-on-start failed (non-fatal)"
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
    if [[ -x "$CLONE_SCRIPT" ]]; then
      log "Hint: Run:"
      log "      ALLOW_WILDCARD=0 bash \"$CLONE_SCRIPT\""
    fi
  fi
fi

log "Docker-in-Docker helper start-up complete."

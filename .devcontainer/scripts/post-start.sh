#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

SUPABASE_PROJECT_DIR="${SUPABASE_PROJECT_DIR:-$REPO_ROOT/supabase}"
SUPABASE_CONFIG_PATH="${SUPABASE_CONFIG_PATH:-$SUPABASE_PROJECT_DIR/config.toml}"
DEVCONTAINER_COMPOSE_FILE="${DEVCONTAINER_COMPOSE_FILE:-$REPO_ROOT/.devcontainer/docker-compose.yml}"
DEVCONTAINER_PROJECT_NAME="${DEVCONTAINER_PROJECT_NAME:-airnub-labs}"

log() { echo "[post-start] $*"; }

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
docker_compose_available=false

if command -v docker >/dev/null 2>&1; then
  docker_cli_present=true
  if wait_for_docker_daemon 40 2; then
    docker_ready=true
    if docker compose version >/dev/null 2>&1; then
      docker_compose_available=true
    else
      log "Docker Compose plugin not available; Redis startup will be skipped."
    fi
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
redis_service_ready=false

if [[ "$docker_ready" == "true" && "$supabase_cli_present" == "true" && "$supabase_project_available" == "true" ]]; then
  supabase_env_helper="$SUPABASE_PROJECT_DIR/scripts/db-env-local.sh"
  if [[ -x "$supabase_env_helper" ]]; then
    log "Ensuring Supabase stack is running and syncing env vars..."
    if command -v pnpm >/dev/null 2>&1; then
      if SUPABASE_ENV_LOG_PREFIX="[post-start]" pnpm db:env:local; then
        supabase_stack_ready=true
        supabase_env_synced=true
      else
        log "pnpm db:env:local failed; attempting direct invocation."
        if SUPABASE_ENV_LOG_PREFIX="[post-start]" "$supabase_env_helper" --ensure-start; then
          supabase_stack_ready=true
          supabase_env_synced=true
        else
          log "Direct Supabase env sync failed; Supabase env vars may be stale."
        fi
      fi
    else
      log "pnpm not available; invoking $supabase_env_helper directly."
      if SUPABASE_ENV_LOG_PREFIX="[post-start]" "$supabase_env_helper" --ensure-start; then
        supabase_stack_ready=true
        supabase_env_synced=true
      else
        log "Supabase env helper failed; Supabase stack may not be ready."
      fi
    fi
  else
    log "Supabase env helper not found at $supabase_env_helper; skipping automatic env sync."
  fi
elif [[ "$supabase_cli_present" != "true" ]]; then
  log "Skipping Supabase startup because the Supabase CLI is unavailable."
elif [[ "$supabase_project_available" != "true" ]]; then
  log "Skipping Supabase startup because supabase/config.toml is missing."
elif [[ "$docker_ready" != "true" ]]; then
  log "Skipping Supabase startup because Docker is unavailable."
fi

ensure_redis_service() {
  if [[ "$docker_compose_available" != "true" ]]; then
    return 1
  fi

  if [[ ! -f "$DEVCONTAINER_COMPOSE_FILE" ]]; then
    log "Devcontainer Docker Compose file not found at $DEVCONTAINER_COMPOSE_FILE; skipping Redis startup."
    return 1
  fi

  local compose_cmd
  compose_cmd=(docker compose --project-name "$DEVCONTAINER_PROJECT_NAME" -f "$DEVCONTAINER_COMPOSE_FILE")

  local running_services
  if running_services="$(${compose_cmd[@]} ps --services --filter status=running 2>/dev/null)"; then
    if grep -qx 'redis' <<<"$running_services"; then
      log "Redis service already running under project '$DEVCONTAINER_PROJECT_NAME'."
      return 0
    fi
  fi

  log "Starting Redis service under project '$DEVCONTAINER_PROJECT_NAME' via Docker Compose..."
  if ${compose_cmd[@]} up -d redis; then
    log "Redis service started."
    return 0
  fi

  log "Failed to start Redis service via Docker Compose."
  return 1
}

if [[ "$docker_ready" == "true" && "$docker_compose_available" == "true" ]]; then
  if ensure_redis_service; then
    redis_service_ready=true
  fi
elif [[ "$docker_ready" != "true" ]]; then
  log "Docker unavailable; unable to manage Redis service."
fi

if [[ "$redis_service_ready" != "true" ]]; then
  if [[ "$docker_ready" == "true" && "$docker_compose_available" != "true" ]]; then
    log "Redis service was not started because the Docker Compose plugin is unavailable."
  fi
fi

if [[ "$supabase_stack_ready" != "true" && "$supabase_cli_present" == "true" && "$supabase_project_available" == "true" ]]; then
  log "Supabase stack was not confirmed ready during post-start."
fi

if [[ "$supabase_env_synced" != "true" && "$supabase_cli_present" == "true" && "$supabase_project_available" == "true" ]]; then
  log "Supabase environment variables were not synced automatically; run 'pnpm db:env:local' once the stack is ready."
fi

# ---------------------------------------------------------------------------
# OPTIONAL: Repo clone support (non-breaking)
# - By default, cloning runs in post-create. Here we only:
#   * Optionally re-run cloning if CLONE_ON_START=true (off by default)
#   * Or emit a helpful hint if workspace repos are missing
# ---------------------------------------------------------------------------

WORKSPACE_ROOT_DEFAULT="$(dirname "$REPO_ROOT")"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$WORKSPACE_ROOT_DEFAULT}"

# Try to locate a .code-workspace file next to this meta repo
WS_FILE="$(find "$REPO_ROOT" -maxdepth 1 -name "*.code-workspace" | head -n 1 || true)"
[[ -n "$WS_FILE" ]] || WS_FILE="$REPO_ROOT/airnub-labs.code-workspace"

# Best-effort jq install if needed
ensure_jq() {
  if command -v jq >/dev/null 2>&1; then return 0; fi
  if command -v apt-get >/dev/null 2>&1; then
    log "jq not found; installing via apt-get..."
    apt-get update -y && apt-get install -y jq || log "jq install failed; proceeding without it"
  else
    log "jq not available and apt-get missing; workspace checks limited"
  fi
}

list_workspace_repo_names() {
  if [[ ! -f "$WS_FILE" ]]; then return 0; fi
  if command -v jq >/dev/null 2>&1; then
    jq -r '.folders[].path' "$WS_FILE" 2>/dev/null | awk -F/ '{print $NF}' | sed '/^\.$/d'
  else
    # minimal python fallback
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

# Optional re-clone on start (off by default)
if [[ "${CLONE_ON_START:-false}" == "true" && -x "$SCRIPT_DIR/clone-from-devcontainer-repos.sh" ]]; then
  ensure_jq
  log "CLONE_ON_START=true → invoking clone-from-devcontainer-repos.sh"
  ALLOW_WILDCARD=0 \
  bash "$SCRIPT_DIR/clone-from-devcontainer-repos.sh" || log "Clone-on-start failed (non-fatal)"
else
  # Emit a helpful hint if any workspace folder is missing as a git repo
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
    log "Hint: Run the clone helper manually:"
    log "      ALLOW_WILDCARD=0 bash \"$SCRIPT_DIR/clone-from-devcontainer-repos.sh\""
  fi
fi

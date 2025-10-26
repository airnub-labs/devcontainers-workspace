#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

SUPABASE_PROJECT_DIR="${SUPABASE_PROJECT_DIR:-$REPO_ROOT/supabase}"
SUPABASE_CONFIG_PATH="${SUPABASE_CONFIG_PATH:-$SUPABASE_PROJECT_DIR/config.toml}"
DEVCONTAINER_COMPOSE_FILE="${DEVCONTAINER_COMPOSE_FILE:-$REPO_ROOT/.devcontainer/docker-compose.yml}"
WORKSPACE_STACK_NAME="${WORKSPACE_STACK_NAME:-${AIRNUB_WORKSPACE_NAME:-airnub-labs}}"
DEVCONTAINER_PROJECT_NAME="${DEVCONTAINER_PROJECT_NAME:-$WORKSPACE_STACK_NAME}"

# Ensure docker compose sees the resolved workspace identifiers when the
# devcontainer invokes it (e.g. for the Redis sidecar) by exporting them into
# the environment before shelling out. When not explicitly overridden we also
# derive a sensible container workspace root that mirrors the stack name.
export WORKSPACE_STACK_NAME
export DEVCONTAINER_PROJECT_NAME

if [[ -z "${WORKSPACE_CONTAINER_ROOT:-}" ]]; then
  WORKSPACE_CONTAINER_ROOT="/airnub-labs"
fi
export WORKSPACE_CONTAINER_ROOT

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

if command -v docker >/dev/null 2>&1; then
  docker_cli_present=true
  if wait_for_docker_daemon 40 2; then
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
    # shellcheck disable=SC2206 # Intentional word splitting for user-provided args
    supabase_start_args+=(${SUPABASE_START_ARGS})
  fi

  if [[ -n "${SUPABASE_START_EXCLUDES:-}" ]]; then
    local exclude
    # shellcheck disable=SC2086 # Word splitting intentional to honour user input
    for exclude in ${SUPABASE_START_EXCLUDES}; do
      supabase_start_args+=(-x "$exclude")
    done
  fi

  if (cd "$supabase_dir" && supabase status >/dev/null 2>&1); then
    log "Supabase stack already running inside the inner Docker daemon."
    return 0
  fi

  local start_display="supabase start"
  if [[ ${#supabase_start_args[@]} -gt 0 ]]; then
    start_display+=" ${supabase_start_args[*]}"
  fi

  log "Supabase stack not running; starting via '$start_display'..."
  if (cd "$supabase_dir" && supabase start "${supabase_start_args[@]}"); then
    log "Supabase stack started successfully."
    return 0
  fi

  log "Failed to start Supabase stack; see Supabase CLI output above for details."
  return 1
}

ensure_inner_redis() {
  if docker ps --format '{{.Names}}' | grep -qx 'redis'; then
    log "Redis container already running inside the inner Docker daemon."
    return 0
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx 'redis'; then
    log "Starting existing Redis container inside the inner Docker daemon..."
    if docker start redis >/dev/null; then
      log "Redis container started."
      return 0
    fi
    log "Failed to start existing Redis container named 'redis'."
    return 1
  fi

  log "Launching Redis container inside the inner Docker daemon..."
  if docker run -d --name redis -p 6379:6379 redis:7-alpine >/dev/null; then
    log "Redis container launched."
    return 0
  fi

  log "Failed to launch Redis container via 'docker run'."
  return 1
}

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
  log "Supabase environment variables were not synced automatically; run './supabase/scripts/db-env-local.sh --ensure-start' once the stack is ready."
fi

if [[ "$redis_container_ready" != "true" && "$docker_ready" == "true" ]]; then
  log "Redis container was not started automatically. Use 'docker start redis' or the provided VS Code task when ready."
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
if [[ -z "$WS_FILE" ]]; then
  local_ws_basename="${WORKSPACE_CODE_WORKSPACE_BASENAME:-$WORKSPACE_STACK_NAME}"
  WS_FILE="$REPO_ROOT/${local_ws_basename}.code-workspace"
fi

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

# --- Fluxbox: menu + autostart Chrome/Chromium in noVNC ---
setup_fluxbox_desktop() {
  set -euo pipefail
  local home_dir="${HOME:-/home/vscode}"
  local fb_dir="$home_dir/.fluxbox"
  mkdir -p "$fb_dir"

  # Pick an installed browser
  local browser_bin=""
  for bin in google-chrome chromium chromium-browser; do
    if command -v "$bin" >/dev/null 2>&1; then browser_bin="$(command -v "$bin")"; break; fi
  done

  # Write a simple Fluxbox menu (right-click desktop)
  cat > "$fb_dir/menu" <<MENU
[begin] (Fluxbox)
  [exec] (XTerm) {xterm}
$( [[ -n "$browser_bin" ]] && echo "  [exec] (Browser) {$browser_bin --start-fullscreen --no-first-run \${BROWSER_AUTOSTART_URL:-about:blank}}" )
  [reconfig] (Reload Menu)
  [exit] (Exit)
[end]
MENU

  # Autostart: Fluxbox's startup hook (run before fluxbox)
  cat > "$fb_dir/startup" <<'STARTUP'
#!/bin/sh
# ~/.fluxbox/startup — launch a browser full screen, then start fluxbox

# Resolve browser at runtime
for bin in google-chrome chromium chromium-browser; do
  if command -v "$bin" >/dev/null 2>&1; then BROWSER_BIN="$bin"; break; fi
done

URL="${BROWSER_AUTOSTART_URL:-about:blank}"
FLAGS="--start-fullscreen --no-first-run --disable-features=TranslateUI"

if [ -n "${BROWSER_BIN:-}" ]; then
  "$BROWSER_BIN" $FLAGS "$URL" &
fi

# Start the WM last
exec fluxbox
STARTUP
  chmod +x "$fb_dir/startup"

  # Fallback: if fluxbox is already up (desktop-lite may start it directly), launch now
  if pgrep -x fluxbox >/dev/null 2>&1; then
    if ! pgrep -f 'google-chrome|chromium' >/dev/null 2>&1 && [[ -n "$browser_bin" ]]; then
      DISPLAY="${DISPLAY:-:1}" "$browser_bin" --start-fullscreen --no-first-run "${BROWSER_AUTOSTART_URL:-about:blank}" >/dev/null 2>&1 &
    fi
  fi

  # Ensure ownership for the vscode user
  chown -R "$(id -un)":"$(id -gn)" "$fb_dir" || true
}

setup_fluxbox_desktop || echo "[post-start] warn: fluxbox desktop setup skipped"

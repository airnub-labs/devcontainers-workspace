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

NOVNC_AUDIO_PORT_EFFECTIVE="${NOVNC_AUDIO_PORT:-6081}"

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
  local container_name="redis"
  local container_image="redis:7-alpine"
  local host_port="6379"

  # Determine whether another container already binds the desired host port so we
  # can bail out early instead of letting `docker start/run` fail with a cryptic
  # "port is already allocated" message.
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
    log "Stop the conflicting container or reconfigure it to free port $host_port, then rerun 'docker start $container_name'."
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


# --- noVNC audio bridge + Fluxbox menu tweaks ---
setup_novnc_audio() {
  set -euo pipefail
  local audio_port="$NOVNC_AUDIO_PORT_EFFECTIVE"
  local novnc_root="/usr/share/novnc"
  local pulse_bin
  local ffmpeg_bin

  pulse_bin="$(command -v pulseaudio || true)"
  ffmpeg_bin="$(command -v ffmpeg || true)"

  if [[ -z "$pulse_bin" || -z "$ffmpeg_bin" ]]; then
    log "Audio bridge prerequisites missing (pulseaudio/ffmpeg); skipping remote audio setup."
    return 0
  fi

  if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR" >/dev/null 2>&1 || true
  fi

  "$pulse_bin" --check >/dev/null 2>&1 || "$pulse_bin" --start >/dev/null 2>&1 || true

  if command -v pactl >/dev/null 2>&1; then
    if ! pactl list short sinks 2>/dev/null | awk '{print $2}' | grep -qx "novnc_sink"; then
      pactl load-module module-null-sink sink_name=novnc_sink sink_properties=device.description=NoVNC >/dev/null 2>&1 || true
    fi
    pactl set-default-sink novnc_sink >/dev/null 2>&1 || true
    while read -r sink_input _; do
      [[ -z "$sink_input" ]] && continue
      pactl move-sink-input "$sink_input" novnc_sink >/dev/null 2>&1 || true
    done < <(pactl list short sink-inputs 2>/dev/null || true)
  fi

  local ffmpeg_pattern="ffmpeg .*novnc_sink\.monitor.*${audio_port}/audio\.ogg"
  if ! pgrep -f "$ffmpeg_pattern" >/dev/null 2>&1; then
    log "Starting background ffmpeg audio bridge on port ${audio_port}..."
    nohup "$ffmpeg_bin" -nostdin -loglevel error \
      -f pulse -i novnc_sink.monitor \
      -ac 2 -ar 44100 \
      -codec:a libopus -b:a 128k \
      -f ogg -content_type audio/ogg \
      -listen 1 "http://0.0.0.0:${audio_port}/audio.ogg" \
      >/tmp/novnc-audio.log 2>&1 &
  fi

  if [[ -d "$novnc_root" ]]; then
    local helper="$novnc_root/app/airnub-audio.js"
    local tmpfile="$(mktemp)"
    cat >"$tmpfile" <<EOF
(function () {
  const params = new URLSearchParams(window.location.search);
  const fallbackPort = ${audio_port};
  let port = parseInt(params.get('audio_port') || '', 10);
  if (!Number.isFinite(port)) {
    port = fallbackPort;
  }
  const proto = window.location.protocol === 'https:' ? 'https:' : 'http:';
  const streamUrl = proto + '//' + window.location.hostname + ':' + port + '/audio.ogg';
  const audio = new Audio(streamUrl);
  audio.autoplay = true;
  audio.loop = true;
  audio.muted = true;
  audio.preload = 'auto';
  audio.playsInline = true;
  audio.style.display = 'none';
  let notice = null;

  const removeNotice = () => {
    if (notice) {
      notice.remove();
      notice = null;
    }
  };

  const ensurePlay = () => {
    audio.play().catch(() => {});
  };

  const showNotice = () => {
    if (!audio.muted || notice) return;
    notice = document.createElement('div');
    notice.innerHTML = 'Remote audio is ready. <strong>Click or press any key</strong> to hear it.';
    notice.style.position = 'fixed';
    notice.style.zIndex = '9999';
    notice.style.top = '12px';
    notice.style.right = '12px';
    notice.style.padding = '10px 14px';
    notice.style.background = 'rgba(0, 0, 0, 0.75)';
    notice.style.color = '#fff';
    notice.style.fontFamily = 'system-ui, sans-serif';
    notice.style.fontSize = '13px';
    notice.style.borderRadius = '8px';
    notice.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.45)';
    notice.style.cursor = 'pointer';
    notice.addEventListener('click', () => {
      audio.muted = false;
      ensurePlay();
      removeNotice();
    }, { once: true });
    document.body.appendChild(notice);
  };

  const handleUserGesture = () => {
    audio.muted = false;
    ensurePlay();
    removeNotice();
    window.removeEventListener('pointerdown', handleUserGesture);
    window.removeEventListener('keydown', handleUserGesture);
  };

  const attachAudio = () => {
    if (!audio.isConnected) {
      document.body.appendChild(audio);
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', attachAudio, { once: true });
  } else {
    attachAudio();
  }

  ensurePlay();
  setTimeout(showNotice, 1200);

  window.addEventListener('pointerdown', handleUserGesture);
  window.addEventListener('keydown', handleUserGesture);
  window.addEventListener('focus', ensurePlay);
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
      ensurePlay();
    }
  });
  audio.addEventListener('playing', removeNotice);
  audio.addEventListener('error', () => {
    setTimeout(ensurePlay, 3000);
  });

  setInterval(() => {
    if (!document.hidden) {
      ensurePlay();
    }
  }, 15000);
})();
EOF
    if command -v sudo >/dev/null 2>&1; then
      sudo tee "$helper" >/dev/null <"$tmpfile"
    else
      cp "$tmpfile" "$helper" || true
    fi
    rm -f "$tmpfile"
    chmod 644 "$helper" >/dev/null 2>&1 || true
    if command -v sudo >/dev/null 2>&1; then
      sudo chown "$(id -un)":"$(id -gn)" "$helper" >/dev/null 2>&1 || true
    else
      chown "$(id -un)":"$(id -gn)" "$helper" >/dev/null 2>&1 || true
    fi

    if [[ -f "$novnc_root/vnc.html" ]] && ! grep -Fq "app/airnub-audio.js" "$novnc_root/vnc.html" 2>/dev/null; then
      tmpfile="$(mktemp)"
      awk '
        /<\/body>/ && !added {
          print "    <script src=\\"app/airnub-audio.js\\"></script>";
          added=1;
        }
        { print }
        END {
          if (!added) {
            print "    <script src=\\"app/airnub-audio.js\\"></script>";
          }
        }
      ' "$novnc_root/vnc.html" >"$tmpfile"
      if command -v sudo >/dev/null 2>&1; then
        sudo tee "$novnc_root/vnc.html" >/dev/null <"$tmpfile"
      else
        cat "$tmpfile" >"$novnc_root/vnc.html" || true
      fi
      rm -f "$tmpfile"
    fi
  fi
}

setup_fluxbox_desktop() {
  set -euo pipefail
  local home_dir="${HOME:-/home/vscode}"
  local fb_dir="$home_dir/.fluxbox"
  local audio_port="$NOVNC_AUDIO_PORT_EFFECTIVE"
  mkdir -p "$fb_dir"

  if [ -d /usr/share/novnc ]; then
    local redirect_url="vnc.html?autoconnect=true&reconnect=true&reconnect_delay=5000&resize=remote&path=websockify&encrypt=0&audio_port=${audio_port}"
    local tmpfile="$(mktemp)"
    cat >"$tmpfile" <<EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0;url=${redirect_url}">
    <title>noVNC</title>
    <style>
      html, body { height: 100%; }
      body {
        margin: 0;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: #111;
        color: #f3f4f6;
        display: flex;
        align-items: center;
        justify-content: center;
        text-align: center;
      }
      a { color: #7db9ff; }
    </style>
  </head>
  <body>
    <p>Opening the remote desktop… <a href="${redirect_url}">Click here if you are not redirected.</a></p>
  </body>
</html>
EOF
    if command -v sudo >/dev/null 2>&1; then
      sudo tee /usr/share/novnc/index.html >/dev/null <"$tmpfile"
    else
      cat "$tmpfile" > /usr/share/novnc/index.html || true
    fi
    rm -f "$tmpfile"
  fi

  local browser_bin=""
  for bin in google-chrome chromium chromium-browser; do
    if command -v "$bin" >/dev/null 2>&1; then browser_bin="$(command -v "$bin")"; break; fi
  done

  cat > "$fb_dir/menu" <<MENU
[begin] (Fluxbox)
  [exec] (XTerm) {xterm}
$( [[ -n "$browser_bin" ]] && echo "  [exec] (Browser) {$browser_bin --no-first-run \${BROWSER_AUTOSTART_URL:-about:blank}}" )
[end]
MENU

  cat > "$fb_dir/startup" <<'STARTUP'
#!/bin/sh
# ~/.fluxbox/startup

for bin in google-chrome chromium chromium-browser; do
  if command -v "$bin" >/dev/null 2>&1; then BROWSER_BIN="$bin"; break; fi
done
URL="${BROWSER_AUTOSTART_URL:-about:blank}"

fluxbox &
fbpid=$!

sleep 1

  if [ -n "${BROWSER_BIN:-}" ]; then
    "$BROWSER_BIN" \
      --no-first-run \
      --disable-gpu \
      --disable-dev-shm-usage \
      --no-default-browser-check \
      "$URL" >/tmp/browser.log 2>&1 &
  fi

if command -v wmctrl >/dev/null 2>&1; then
  for i in $(seq 1 20); do
    WID="$(wmctrl -lx 2>/dev/null | awk '/chrom|google-chrome/ {print $1; exit}')"
    if [ -n "$WID" ]; then
      wmctrl -i -r "$WID" -b add,fullscreen
      break
    fi
    sleep 0.5
  done
fi

wait $fbpid
STARTUP
  chmod +x "$fb_dir/startup"

  if command -v fluxbox-remote >/dev/null 2>&1; then
    fluxbox-remote reconfigure >/dev/null 2>&1 || true
  fi

  chown -R "$(id -un)":"$(id -gn)" "$fb_dir" || true
}

setup_novnc_audio || echo "[post-start] warn: remote audio setup skipped"
setup_fluxbox_desktop || echo "[post-start] warn: fluxbox desktop setup skipped"


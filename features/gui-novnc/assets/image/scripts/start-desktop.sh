#!/usr/bin/env bash
set -euo pipefail

# ----------------- Config via envs -----------------
: "${NOVNC_AUTOCONNECT:=1}"
: "${NOVNC_RESIZE:=scale}"       # scale | downscale | remote | off
: "${NOVNC_RECONNECT:=1}"
: "${NOVNC_VIEW_ONLY:=0}"
: "${NOVNC_PATH:=websockify}"
: "${APP_URL:=about:blank}"
: "${NOVNC_AUDIO_ENABLE:=0}"     # 1 to enable audio bridge
: "${NOVNC_AUDIO_PORT:=6081}"    # used if audio is enabled
: "${CDP_PORT:=9222}"
: "${CHROME_USER_DATA_DIR:=/tmp/chrome-profile-stable}"
: "${CHROME_ARGS:=}"
: "${CHROME_WIDTH:=1280}"
: "${CHROME_HEIGHT:=800}"
: "${CHROME_FULLSCREEN:=0}"   # 1 = fullscreen, 0 = use window-size

export DISPLAY="${DISPLAY:-:99}"

# --------------- Stable Xauthority for :99 ---------------
XNUM="${DISPLAY#:}"
XAUTHORITY="${XAUTHORITY:-/tmp/Xvfb${XNUM}.Xauthority}"
export DISPLAY=":${XNUM}"
export XAUTHORITY

mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

if [ -f "/tmp/.X${XNUM}-lock" ]; then
  LOCKPID="$(cat "/tmp/.X${XNUM}-lock" 2>/dev/null || true)"
  if ! ps -p "${LOCKPID:-}" >/dev/null 2>&1; then
    rm -f "/tmp/.X${XNUM}-lock" "/tmp/.X11-unix/X${XNUM}" || true
  fi
fi

if ! xauth -f "$XAUTHORITY" list :"$XNUM" >/dev/null 2>&1; then
  COOKIE="$(command -v mcookie >/dev/null 2>&1 && mcookie || head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  xauth -f "$XAUTHORITY" add :"$XNUM" MIT-MAGIC-COOKIE-1 "$COOKIE"
  chmod 600 "$XAUTHORITY"
fi

# --------------- Virtual display & WM ---------------
Xvfb ":${XNUM}" -screen 0 1920x1080x24 -nolisten tcp -auth "$XAUTHORITY" &
XVFB_PID=$!
sleep 0.5

fluxbox &

# ------------------- VNC server ---------------------
while true; do
  x11vnc -display ":${XNUM}" -auth "$XAUTHORITY" \
         -forever -shared -rfbport 5900 -nopw -quiet && break
  echo "[gui] x11vnc exited; retrying in 2s..."
  sleep 2
done &

# --------- Prepare noVNC root with redirect --------
NOVNC_ROOT=/opt/novnc
if [ ! -d "$NOVNC_ROOT" ]; then
  mkdir -p "$NOVNC_ROOT"
  if [ -d /usr/share/novnc ]; then
    cp -a /usr/share/novnc/* "$NOVNC_ROOT/"
  fi
fi

# Build redirect query string (include audio when enabled)
NOVNC_QUERY="autoconnect=${NOVNC_AUTOCONNECT}&reconnect=${NOVNC_RECONNECT}&resize=${NOVNC_RESIZE}&view_only=${NOVNC_VIEW_ONLY}&path=${NOVNC_PATH}"
if [ "${NOVNC_AUDIO_ENABLE}" = "1" ]; then
  NOVNC_QUERY="${NOVNC_QUERY}&audio_port=${NOVNC_AUDIO_PORT}"
fi

cat >"$NOVNC_ROOT/index.html" <<EOF
<!doctype html><meta charset="utf-8">
<title>noVNC</title>
<meta http-equiv="refresh" content="0; URL=./vnc.html?${NOVNC_QUERY}">
<script>location.replace('./vnc.html?${NOVNC_QUERY}');</script>
EOF

if [ "${NOVNC_AUDIO_ENABLE}" = "1" ]; then
  NOVNC_AUDIO_PORT_EFFECTIVE="${NOVNC_AUDIO_PORT}" \
  novnc-audio-bridge.sh "$NOVNC_ROOT" || echo "[gui] audio bridge skipped"
fi

# ---------------- websockify/noVNC ------------------
websockify --web="$NOVNC_ROOT" 0.0.0.0:6080 localhost:5900 &

# ------------------ Launch Chrome -------------------
CHROME_CMD=(
  "${CHROME_BIN:-google-chrome}"
  --no-first-run --no-default-browser-check
  --disable-dev-shm-usage --disable-gpu
  --user-data-dir="${CHROME_USER_DATA_DIR}"
  --remote-debugging-address=0.0.0.0
  --remote-debugging-port="${CDP_PORT}"
)

if [ "${CHROME_FULLSCREEN}" = "1" ]; then
  CHROME_CMD+=(--start-fullscreen)
else
  CHROME_CMD+=(
    --new-window
    --window-size="${CHROME_WIDTH},${CHROME_HEIGHT}"
    --window-position=0,0
  )
fi

# Optional: if Chrome ignores window-size due to saved bounds in the profile
# uncomment the next line to reset them on each start:
# rm -f "${CHROME_USER_DATA_DIR}/Default/Preferences" 2>/dev/null || true

if [ -n "${CHROME_ARGS}" ]; then
  # shellcheck disable=SC2206  # intentional word splitting to honour extra args
  EXTRA_ARGS=( ${CHROME_ARGS} )
  CHROME_CMD+=("${EXTRA_ARGS[@]}")
fi

CHROME_CMD+=("${APP_URL}")

"${CHROME_CMD[@]}" &

if command -v wmctrl >/dev/null 2>&1 && [ "${CHROME_FULLSCREEN}" != "1" ]; then
  for i in $(seq 1 30); do
    WID="$(wmctrl -lx 2>/dev/null | awk '/chrom|google-chrome/ {print $1; exit}')"
    [ -n "$WID" ] && { wmctrl -i -r "$WID" -e "0,0,0,${CHROME_WIDTH},${CHROME_HEIGHT}"; break; }
    sleep 0.2
  done
fi

wait "$XVFB_PID"

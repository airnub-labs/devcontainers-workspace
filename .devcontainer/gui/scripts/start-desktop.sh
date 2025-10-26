#!/usr/bin/env bash
set -euo pipefail

# ----------------- Config via envs -----------------
: "${NOVNC_AUTOCONNECT:=1}"
: "${NOVNC_RESIZE:=scale}"       # scale | downscale | remote | off
: "${NOVNC_RECONNECT:=1}"
: "${NOVNC_VIEW_ONLY:=0}"
: "${APP_URL:=about:blank}"
: "${NOVNC_AUDIO_ENABLE:=0}"     # 1 to enable audio bridge
: "${NOVNC_AUDIO_PORT:=6081}"    # used if audio is enabled

export DISPLAY=${DISPLAY:-:99}

CDP_PORT="${CDP_PORT:-9222}"

# --------------- Virtual desktop & WM ---------------
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
sleep 0.5
fluxbox &

# ------------------- VNC server ---------------------
x11vnc -forever -shared -rfbport 5900 -display :99 -nopw -quiet &

# --------- Prepare noVNC root with redirect --------
NOVNC_ROOT=/opt/novnc
if [ ! -d "$NOVNC_ROOT" ]; then
  mkdir -p "$NOVNC_ROOT"
  cp -a /usr/share/novnc/* "$NOVNC_ROOT/"
fi

if command -v apply-chrome-policy.sh >/dev/null 2>&1; then
  apply-chrome-policy.sh || echo "[gui] Chrome policy application failed (continuing)"
fi

# Redirect index.html to vnc.html with desired params
cat >"$NOVNC_ROOT/index.html" <<EOF
<!doctype html><meta charset="utf-8">
<title>noVNC</title>
<meta http-equiv="refresh"
  content="0; URL=./vnc.html?autoconnect=${NOVNC_AUTOCONNECT}&reconnect=${NOVNC_RECONNECT}&resize=${NOVNC_RESIZE}&view_only=${NOVNC_VIEW_ONLY}">
<script>location.replace('./vnc.html?autoconnect=${NOVNC_AUTOCONNECT}&reconnect=${NOVNC_RECONNECT}&resize=${NOVNC_RESIZE}&view_only=${NOVNC_VIEW_ONLY}');</script>
EOF

# (Optional) setup Fluxbox defaults/menu/startup (no-ops if it fails)
fluxbox-setup.sh || true

# (Optional) audio bridge (adds <script> to vnc.html)
if [ "${NOVNC_AUDIO_ENABLE}" = "1" ]; then
  NOVNC_AUDIO_PORT_EFFECTIVE="${NOVNC_AUDIO_PORT}" \
  novnc-audio-bridge.sh "$NOVNC_ROOT" || echo "[gui] audio bridge skipped"
fi

# ---------------- websockify/noVNC ------------------
websockify --web="$NOVNC_ROOT" 0.0.0.0:6080 localhost:5900 &

# ------------------ Launch Chrome -------------------
"${CHROME_BIN:-google-chrome}" \
  --no-first-run --no-default-browser-check \
  --no-sandbox --disable-dev-shm-usage --disable-gpu \
  --start-fullscreen \
  --remote-debugging-address=0.0.0.0 \
  --remote-debugging-port="${CDP_PORT}" \  
  "${APP_URL:-about:blank}" &

wait -n

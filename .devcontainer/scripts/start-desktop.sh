#!/usr/bin/env bash
set -euo pipefail

# Launch Xvfb (virtual display)
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
sleep 0.5

# Lightweight WM so Chrome can fullscreen etc.
fluxbox &

# Expose the display over VNC
x11vnc -forever -shared -rfbport 5900 -display :99 -nopw -quiet &

# noVNC: serve VNC over WebSockets on :6080
websockify --web=/usr/share/novnc 0.0.0.0:6080 localhost:5900 &

# Optional: open a URL in Chrome inside the desktop (defaults to blank)
${CHROME_BIN:-google-chrome} \
  --no-first-run --no-default-browser-check \
  --no-sandbox --disable-dev-shm-usage \
  --window-size=1600,900 \
  "${APP_URL:-about:blank}" &

# Wait on the first background job to exit
wait -n

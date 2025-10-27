#!/usr/bin/env bash
set -euo pipefail

# System defaults (used when per-user config is absent)
# Menu
mkdir -p /etc/X11/fluxbox
cat > /etc/X11/fluxbox/menu <<'MENU'
[begin] (Fluxbox)
  [exec] (XTerm) {xterm}
  [exec] (Chrome) {google-chrome --no-first-run --disable-gpu --disable-dev-shm-usage --no-default-browser-check ${BROWSER_AUTOSTART_URL:-about:blank}}
[end]
MENU

# Startup (auto fullscreen Chrome if available)
cat > /etc/X11/fluxbox/startup <<'STARTUP'
#!/bin/sh
# System-wide startup; per-user ~/.fluxbox/startup overrides if present

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
chmod +x /etc/X11/fluxbox/startup

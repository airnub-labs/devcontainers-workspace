#!/usr/bin/env bash
set -eu
: "${GUI_CHROME_DEBUG:=1}"
: "${GUI_WEBTOP_DEVTOOLS_PORT:=9223}"
: "${WEBTOP_START_URL:=http://devcontainer:54323}"

if [ "${GUI_CHROME_DEBUG}" = "1" ]; then
  if command -v chromium-browser >/dev/null 2>&1; then
    nohup chromium-browser --remote-debugging-address=0.0.0.0 --remote-debugging-port="${GUI_WEBTOP_DEVTOOLS_PORT}" >/dev/null 2>&1 &
  elif command -v google-chrome >/dev/null 2>&1; then
    nohup google-chrome --remote-debugging-address=0.0.0.0 --remote-debugging-port="${GUI_WEBTOP_DEVTOOLS_PORT}" >/dev/null 2>&1 &
  fi
fi

if [ -n "${WEBTOP_START_URL}" ]; then
  browser_cmd=""
  if command -v chromium-browser >/dev/null 2>&1; then
    browser_cmd="/usr/bin/chromium-browser --no-first-run --password-store=basic"
  elif command -v google-chrome >/dev/null 2>&1; then
    browser_cmd="/usr/bin/google-chrome --no-first-run --password-store=basic"
  fi

  if [ -n "$browser_cmd" ]; then
    autostart_dir="/config/.config/autostart"
    autostart_entry="${autostart_dir}/supabase-studio.desktop"
    mkdir -p "$autostart_dir"
    cat >"$autostart_entry" <<EOF
[Desktop Entry]
Type=Application
Name=Supabase Studio
Comment=Open Supabase Studio on login
Exec=${browser_cmd} ${WEBTOP_START_URL}
X-GNOME-Autostart-enabled=true
Terminal=false
EOF
    chmod 644 "$autostart_entry"
  fi
fi

#!/usr/bin/env bash
set -eu
: "${GUI_CHROME_DEBUG:=1}"
: "${GUI_CHROME_DEVTOOLS_PORT:=9224}"

if [ "${GUI_CHROME_DEBUG}" = "1" ]; then
  if command -v chromium-browser >/dev/null 2>&1; then
    nohup chromium-browser --remote-debugging-address=0.0.0.0 --remote-debugging-port="${GUI_CHROME_DEVTOOLS_PORT}" >/dev/null 2>&1 &
  elif command -v google-chrome >/dev/null 2>&1; then
    nohup google-chrome --remote-debugging-address=0.0.0.0 --remote-debugging-port="${GUI_CHROME_DEVTOOLS_PORT}" >/dev/null 2>&1 &
  fi
fi

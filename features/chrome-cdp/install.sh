#!/usr/bin/env bash
set -euo pipefail

CHANNEL="${CHANNEL:-stable}"
PORT="${PORT:-9222}"
FEATURE_DIR="/usr/local/share/devcontainer/features/chrome-cdp"
CONFIG_DIR="/usr/local/share/chrome-cdp"
PROFILE_DIR="/etc/profile.d"

mkdir -p "${FEATURE_DIR}" "${CONFIG_DIR}"

ARCH=$(dpkg --print-architecture)
CHROME_BIN=""

install_supervisor() {
    if command -v supervisord >/dev/null 2>&1; then
        return 0
    fi

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends supervisor
}

install_chrome() {
    apt-get update

    if [ "${ARCH}" != "amd64" ]; then
        if DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends chromium; then
            :
        elif DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends chromium-browser; then
            :
        else
            echo "[chrome-cdp] Unable to install Chromium for architecture ${ARCH}." >&2
            exit 1
        fi

        CHROME_BIN=$(command -v chromium || command -v chromium-browser || true)
        if [ -z "${CHROME_BIN}" ]; then
            echo "[chrome-cdp] Chromium binary not found after installation." >&2
            exit 1
        fi

        ln -sf "${CHROME_BIN}" /usr/local/bin/google-chrome
        return 0
    fi

    if [ ! -f /usr/share/keyrings/google-chrome.gpg ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gnupg
        curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor >/usr/share/keyrings/google-chrome.gpg
    fi

    cat <<'APT' >/etc/apt/sources.list.d/google-chrome.list
deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main
APT

    apt-get update
    local package="google-chrome-${CHANNEL}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${package}"

    CHROME_BIN=$(command -v google-chrome || true)
}

configure_supervisor() {
    if [ -z "${CHROME_BIN}" ]; then
        CHROME_BIN=$(command -v google-chrome || command -v chromium || command -v chromium-browser || echo "/usr/bin/google-chrome")
    fi

    local supervisord_conf="${CONFIG_DIR}/supervisord.conf"
    cat <<EOF_SUP >"${supervisord_conf}"
[supervisord]
nodaemon=true
logfile=/tmp/chrome-cdp-supervisord.log
pidfile=/tmp/chrome-cdp-supervisord.pid
environment=CDP_PORT="${PORT}"

[program:chrome-cdp]
command=${CHROME_BIN} --headless --disable-gpu --remote-debugging-address=0.0.0.0 --remote-debugging-port=${PORT} about:blank
autostart=true
autorestart=true
stdout_logfile=/tmp/chrome-cdp.log
stderr_logfile=/tmp/chrome-cdp.err
EOF_SUP

    cat <<'EOF_START' >"${CONFIG_DIR}/start-supervisord.sh"
#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/usr/local/share/chrome-cdp"
SUPERVISORD_CONF="${CONFIG_DIR}/supervisord.conf"
SUPERVISORD_BIN="$(command -v supervisord)"
BOOTSTRAP_LOG="/tmp/chrome-cdp-bootstrap.log"
PORT="${CDP_PORT:-9222}"
READY_TIMEOUT="${CDP_READY_TIMEOUT:-45}"
READY_INTERVAL="${CDP_READY_INTERVAL:-1}"

log() {
    echo "[chrome-cdp] $*" >&2
}

supervisord_running() {
    pgrep -f "supervisord.*chrome-cdp" >/dev/null 2>&1
}

is_ready() {
    local endpoint="http://127.0.0.1:${PORT}/json/version"
    if command -v curl >/dev/null 2>&1; then
        if curl -fsS --max-time 2 "${endpoint}" >/dev/null 2>&1; then
            return 0
        fi
        return 1
    fi

    if command -v wget >/dev/null 2>&1; then
        if wget -qO- --timeout=2 "${endpoint}" >/dev/null 2>&1; then
            return 0
        fi
        return 1
    fi

    if command -v python3 >/dev/null 2>&1; then
        if python3 - <<PYTHON >/dev/null 2>&1
import sys
from urllib import request

try:
    request.urlopen("${endpoint}", timeout=2)
except Exception:
    sys.exit(1)
PYTHON
        then
            return 0
        fi
    fi

    if exec 3<>"/dev/tcp/127.0.0.1/${PORT}" 2>/dev/null; then
        exec 3>&-
        exec 3<&-
        return 0
    fi

    return 1
}

wait_for_readiness() {
    local start_ts
    start_ts=$(date +%s)

    if is_ready; then
        log "DevTools endpoint available on port ${PORT}."
        return 0
    fi

    while true; do
        if ! supervisord_running; then
            log "supervisord exited before the DevTools endpoint became ready."
            return 1
        fi

        local now elapsed
        now=$(date +%s)
        elapsed=$((now - start_ts))
        if (( elapsed >= READY_TIMEOUT )); then
            log "Timed out waiting ${READY_TIMEOUT}s for the DevTools endpoint on port ${PORT}."
            return 1
        fi

        sleep "${READY_INTERVAL}"

        if is_ready; then
            log "DevTools endpoint available on port ${PORT}."
            return 0
        fi
    done
}

start_supervisord() {
    if supervisord_running; then
        return 0
    fi

    "${SUPERVISORD_BIN}" -c "${SUPERVISORD_CONF}" >"${BOOTSTRAP_LOG}" 2>&1 &
    sleep 1
}

start_supervisord
if ! wait_for_readiness; then
    # Don't fail the shell session, but emit diagnostics for CI logs.
    exit 0
fi
EOF_START
    chmod +x "${CONFIG_DIR}/start-supervisord.sh"

    cat <<EOF_ENV >"${PROFILE_DIR}/chrome-cdp.sh"
export CDP_PORT=${PORT}
if [ -z "${SKIP_CHROME_CDP:-}" ] && command -v supervisord >/dev/null 2>&1; then
    if ! pgrep -f "supervisord.*chrome-cdp" >/dev/null 2>&1; then
        "${CONFIG_DIR}/start-supervisord.sh"
    fi
fi
EOF_ENV
}

install_supervisor
install_chrome
configure_supervisor

cat <<EOF_NOTE >"${FEATURE_DIR}/feature-installed.txt"
channel=${CHANNEL}
port=${PORT}
arch=${ARCH}
binary=${CHROME_BIN}
EOF_NOTE

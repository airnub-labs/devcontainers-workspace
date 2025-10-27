#!/usr/bin/env bash
set -euo pipefail

CHANNEL="${CHANNEL:-stable}"
PORT="${PORT:-9222}"
FEATURE_DIR="/usr/local/share/devcontainer/features/chrome-cdp"
CONFIG_DIR="/usr/local/share/chrome-cdp"
PROFILE_DIR="/etc/profile.d"

mkdir -p "${FEATURE_DIR}" "${CONFIG_DIR}"

ARCH=$(dpkg --print-architecture)

install_supervisor() {
    if command -v supervisord >/dev/null 2>&1; then
        return 0
    fi
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends supervisor
}

install_chrome_repo() {
    if [ "${ARCH}" != "amd64" ]; then
        # Rely on chromium from Debian repositories for non-amd64 architectures.
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends chromium
        ln -sf "/usr/bin/chromium" "/usr/local/bin/google-chrome"
        return 0
    fi

    if [ ! -f /usr/share/keyrings/google-chrome.gpg ]; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gnupg
        curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor >/usr/share/keyrings/google-chrome.gpg
    fi

    cat <<'APT' >/etc/apt/sources.list.d/google-chrome.list
deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main
APT

    apt-get update
    local package="google-chrome-${CHANNEL}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${package}"
}

configure_supervisor() {
    cat <<EOF_SUP >/usr/local/share/chrome-cdp/supervisord.conf
[supervisord]
nodaemon=true
logfile=/tmp/chrome-cdp-supervisord.log
pidfile=/tmp/chrome-cdp-supervisord.pid
environment=CDP_PORT="${PORT}"

[program:chrome-cdp]
command=/usr/bin/google-chrome --headless --disable-gpu --remote-debugging-address=0.0.0.0 --remote-debugging-port=${PORT} about:blank
autostart=true
autorestart=true
stdout_logfile=/tmp/chrome-cdp.log
stderr_logfile=/tmp/chrome-cdp.err
EOF_SUP

    cat <<'EOF_START' >/usr/local/share/chrome-cdp/start-supervisord.sh
#!/usr/bin/env bash
set -euo pipefail
SUPERVISORD_CONF="/usr/local/share/chrome-cdp/supervisord.conf"
SUPERVISORD_BIN="$(command -v supervisord)"
if pgrep -f "supervisord.*chrome-cdp" >/dev/null 2>&1; then
    exit 0
fi
"${SUPERVISORD_BIN}" -c "${SUPERVISORD_CONF}" >/tmp/chrome-cdp-bootstrap.log 2>&1 &
EOF_START
    chmod +x /usr/local/share/chrome-cdp/start-supervisord.sh

    cat <<EOF_ENV >"${PROFILE_DIR}/chrome-cdp.sh"
export CDP_PORT=${PORT}
if [ -z "${SKIP_CHROME_CDP:-}" ] && command -v supervisord >/dev/null 2>&1; then
    if ! pgrep -f "supervisord.*chrome-cdp" >/dev/null 2>&1; then
        /usr/local/share/chrome-cdp/start-supervisord.sh
    fi
fi
EOF_ENV
}

install_supervisor
install_chrome_repo
configure_supervisor

cat <<EOF_NOTE >"${FEATURE_DIR}/feature-installed.txt"
channel=${CHANNEL}
port=${PORT}
arch=${ARCH}
EOF_NOTE

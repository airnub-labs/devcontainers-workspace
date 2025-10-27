#!/usr/bin/env bash
set -euo pipefail

INSTALL_CODEX="${INSTALLCODEX:-true}"
INSTALL_CLAUDE="${INSTALLCLAUDE:-false}"
INSTALL_GEMINI="${INSTALLGEMINI:-false}"
VERSION_JSON="${VERSIONS:-}"
VERSION_CODEX="${VERSIONS__CODEX:-}"
VERSION_CLAUDE="${VERSIONS__CLAUDE:-}"
VERSION_GEMINI="${VERSIONS__GEMINI:-}"
FEATURE_DIR="/usr/local/share/devcontainer/features/mcp-clis"

mkdir -p "${FEATURE_DIR}"

parse_version_json() {
    local key="$1"
    if [ -z "${VERSION_JSON}" ]; then
        return 0
    fi
    python3 - <<PYTHON
import json, os
raw = os.environ.get("VERSION_JSON", "")
key = os.environ.get("KEY")
if not raw:
    raise SystemExit(0)
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    raise SystemExit(0)
value = data.get(key)
if value:
    print(value)
PYTHON
}

if [ -z "${VERSION_CODEX}" ]; then
    VERSION_CODEX=$(KEY="codex" VERSION_JSON="${VERSION_JSON}" parse_version_json codex)
fi
if [ -z "${VERSION_CLAUDE}" ]; then
    VERSION_CLAUDE=$(KEY="claude" VERSION_JSON="${VERSION_JSON}" parse_version_json claude)
fi
if [ -z "${VERSION_GEMINI}" ]; then
    VERSION_GEMINI=$(KEY="gemini" VERSION_JSON="${VERSION_JSON}" parse_version_json gemini)
fi

install_cli() {
    local name="$1"
    local package="$2"
    local binary="$3"
    local version="$4"

    if [ "${name}" = "codex" ] && ! ${INSTALL_CODEX}; then
        return 0
    fi
    if [ "${name}" = "claude" ] && ! ${INSTALL_CLAUDE}; then
        return 0
    fi
    if [ "${name}" = "gemini" ] && ! ${INSTALL_GEMINI}; then
        return 0
    fi

    if command -v "${binary}" >/dev/null 2>&1; then
        echo "[mcp-clis] ${binary} already installed; skipping."
        return 0
    fi

    if ! command -v pnpm >/dev/null 2>&1; then
        echo "[mcp-clis] pnpm is required to install ${binary}; skipping." >&2
        return 0
    fi

    local target="${package}"
    if [ -n "${version}" ]; then
        target="${package}@${version}"
    fi

    echo "[mcp-clis] Installing ${target}"
    if pnpm install -g "${target}"; then
        echo "[mcp-clis] ${binary} installation complete."
    else
        echo "[mcp-clis] Failed to install ${binary}; continuing without it." >&2
    fi
}

install_cli "codex" "@openai/codex" "codex" "${VERSION_CODEX}"
install_cli "claude" "@anthropic-ai/claude-code" "claude" "${VERSION_CLAUDE}"
install_cli "gemini" "@google/gemini-cli" "gemini" "${VERSION_GEMINI}"

cat <<EOF_NOTE >"${FEATURE_DIR}/feature-installed.txt"
installCodex=${INSTALL_CODEX}
installClaude=${INSTALL_CLAUDE}
installGemini=${INSTALL_GEMINI}
versionCodex=${VERSION_CODEX}
versionClaude=${VERSION_CLAUDE}
versionGemini=${VERSION_GEMINI}
EOF_NOTE

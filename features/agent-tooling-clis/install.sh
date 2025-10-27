#!/usr/bin/env bash
set -euo pipefail

INSTALL_CODEX="${INSTALLCODEX:-true}"
INSTALL_CLAUDE="${INSTALLCLAUDE:-false}"
INSTALL_GEMINI="${INSTALLGEMINI:-false}"
VERSION_JSON="${VERSIONS:-}"
VERSION_CODEX="${VERSIONS__CODEX:-}"
VERSION_CLAUDE="${VERSIONS__CLAUDE:-}"
VERSION_GEMINI="${VERSIONS__GEMINI:-}"
FEATURE_DIR="/usr/local/share/devcontainer/features/agent-tooling-clis"
LAST_INSTALLED_VERSION=""

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

trim_first_line() {
    python3 - <<'PYTHON'
import sys
data = sys.stdin.read().splitlines()
if data:
    print(data[0].strip())
PYTHON
}

select_package_manager() {
    if command -v pnpm >/dev/null 2>&1; then
        printf 'pnpm'
        return 0
    fi
    if command -v npm >/dev/null 2>&1; then
        printf 'npm'
        return 0
    fi
    printf ''
}

resolve_latest_version() {
    local package="$1"
    local preferred="${2:-}"
    local version=""
    local result=""

    if [ "${preferred}" = "pnpm" ] && command -v pnpm >/dev/null 2>&1; then
        result=$(pnpm view "${package}" version 2>/dev/null || true)
        if [ -n "${result}" ]; then
            version=$(printf '%s' "${result}" | trim_first_line)
        fi
    elif [ "${preferred}" = "npm" ] && command -v npm >/dev/null 2>&1; then
        result=$(npm view "${package}" version 2>/dev/null || true)
        if [ -n "${result}" ]; then
            version=$(printf '%s' "${result}" | trim_first_line)
        fi
    fi

    if [ -z "${version}" ] && command -v pnpm >/dev/null 2>&1; then
        result=$(pnpm view "${package}" version 2>/dev/null || true)
        if [ -n "${result}" ]; then
            version=$(printf '%s' "${result}" | trim_first_line)
        fi
    fi

    if [ -z "${version}" ] && command -v npm >/dev/null 2>&1; then
        result=$(npm view "${package}" version 2>/dev/null || true)
        if [ -n "${result}" ]; then
            version=$(printf '%s' "${result}" | trim_first_line)
        fi
    fi

    printf '%s' "${version}"
}

get_cli_version() {
    local binary="$1"
    if ! command -v "${binary}" >/dev/null 2>&1; then
        return 0
    fi

    local output
    output=$("${binary}" --version 2>/dev/null || true)
    if [ -z "${output}" ]; then
        return 0
    fi

    printf '%s' "${output}" | python3 - <<'PYTHON'
import re
import sys

data = sys.stdin.read()
match = re.search(r"(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)", data)
if match:
    print(match.group(1))
else:
    lines = [line.strip() for line in data.splitlines() if line.strip()]
    if lines:
        print(lines[0])
PYTHON
}

install_cli() {
    local name="$1"
    local package="$2"
    local binary="$3"
    local version="$4"

    LAST_INSTALLED_VERSION=""

    case "${name}" in
        codex)
            [ "${INSTALL_CODEX}" = "true" ] || return 0
            ;;
        claude)
            [ "${INSTALL_CLAUDE}" = "true" ] || return 0
            ;;
        gemini)
            [ "${INSTALL_GEMINI}" = "true" ] || return 0
            ;;
    esac

    local manager
    manager=$(select_package_manager)
    if [ -z "${manager}" ]; then
        echo "[agent-tooling-clis] Neither pnpm nor npm is available to install ${binary}; skipping." >&2
        return 0
    fi

    local requested_version="${version}"
    if [ "${requested_version}" = "latest" ]; then
        requested_version=""
    fi

    local desired_version="${requested_version}"
    if [ -z "${desired_version}" ]; then
        desired_version=$(resolve_latest_version "${package}" "${manager}")
    fi

    local installed_version
    installed_version=$(get_cli_version "${binary}")

    local desired_label="${desired_version}"
    if [ -z "${desired_label}" ]; then
        if [ -n "${requested_version}" ]; then
            desired_label="${requested_version}"
        else
            desired_label="latest"
        fi
    fi

    local current_label="${installed_version}"
    if [ -z "${current_label}" ]; then
        current_label="(not installed)"
    fi

    echo "[agent-tooling-clis] ${binary}: current version ${current_label}, desired ${desired_label}."

    local needs_install="true"
    if [ -n "${installed_version}" ]; then
        if [ -n "${desired_version}" ] && [ "${installed_version}" = "${desired_version}" ]; then
            needs_install="false"
        elif [ -z "${desired_version}" ] && [ -n "${requested_version}" ] && [ "${installed_version}" = "${requested_version}" ]; then
            needs_install="false"
        elif [ -z "${desired_version}" ] && [ -z "${requested_version}" ]; then
            needs_install="false"
        fi
    fi

    local target="${package}"
    local install_success="false"

    if [ "${needs_install}" = "true" ]; then
        local version_to_install="${desired_version}"
        if [ -z "${version_to_install}" ] && [ -n "${requested_version}" ]; then
            version_to_install="${requested_version}"
        fi

        if [ -n "${version_to_install}" ]; then
            target="${package}@${version_to_install}"
        fi

        local installer=( )
        if [ "${manager}" = "pnpm" ]; then
            installer=(pnpm add --global "${target}")
        else
            installer=(npm install -g "${target}")
        fi

        echo "[agent-tooling-clis] Installing ${target} via ${installer[0]}"
        if "${installer[@]}"; then
            echo "[agent-tooling-clis] ${binary} installation complete."
            install_success="true"
        else
            echo "[agent-tooling-clis] Failed to install ${binary}; continuing without it." >&2
        fi
    else
        echo "[agent-tooling-clis] ${binary} already satisfies the requested version; skipping reinstall."
    fi

    local final_version="${installed_version}"
    if [ "${install_success}" = "true" ]; then
        final_version=$(get_cli_version "${binary}")
        if [ -z "${final_version}" ]; then
            final_version="${desired_version}"
        fi
    fi

    LAST_INSTALLED_VERSION="${final_version}"
}

install_cli "codex" "@openai/codex" "codex" "${VERSION_CODEX}"
RESOLVED_CODEX="${LAST_INSTALLED_VERSION}"
install_cli "claude" "@anthropic-ai/claude-code" "claude" "${VERSION_CLAUDE}"
RESOLVED_CLAUDE="${LAST_INSTALLED_VERSION}"
install_cli "gemini" "@google/gemini-cli" "gemini" "${VERSION_GEMINI}"
RESOLVED_GEMINI="${LAST_INSTALLED_VERSION}"

cat <<EOF_NOTE >"${FEATURE_DIR}/feature-installed.txt"
installCodex=${INSTALL_CODEX}
installClaude=${INSTALL_CLAUDE}
installGemini=${INSTALL_GEMINI}
versionCodex=${RESOLVED_CODEX:-${VERSION_CODEX}}
versionClaude=${RESOLVED_CLAUDE:-${VERSION_CLAUDE}}
versionGemini=${RESOLVED_GEMINI:-${VERSION_GEMINI}}
EOF_NOTE
